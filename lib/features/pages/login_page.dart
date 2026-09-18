import 'package:firma_tap/core/auth/biometric_service.dart';
import 'package:firma_tap/core/storage/auth_storage.dart';
import 'package:firma_tap/features/services/empresa_service.dart';
import 'package:firma_tap/features/models/empresa_dto.dart';
import 'package:firma_tap/features/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  //final _empresaController = TextEditingController(text: 'EC'); // valor por defecto
  List<EmpresaDTO> _empresas = [];
  EmpresaDTO? _empresaSeleccionada;
  String _biometriaLabel = 'huella / Face ID';

  @override
  void initState() {
    super.initState();
    _checkLogin();
    _cargarEmpresas();
    _cargarEtiquetaBiometria();
  }

  Future<void> _cargarEtiquetaBiometria() async {
    try {
      final label = await BiometricService().getBiometryLabel();
      if (mounted) setState(() => _biometriaLabel = label);
    } catch (_) {}
  }

  Future<void> _checkLogin() async {
    final userId = await AuthStorage.getUsuarioId();
    final empresa = await AuthStorage.getEmpresa();
    if (userId != null && empresa != null && empresa.isNotEmpty) {
      // Si hay biometría disponible, pedirla antes de entrar automático
      try {
        final bio = BiometricService();
        if (await bio.isBiometricAvailable()) {
          final ok = await bio.authenticate();
          if (!ok) return;
        }
      } catch (_) {}
      if (mounted) _goToDocumentos(userId, empresa);
    }
  }

  Future<void> _loginBiometrico() async {
    try {
      final bio = BiometricService();
      if (!await bio.isBiometricAvailable()) {
        // Diagnóstico extra: ver si es por no enrolado
        final available = await bio.getAvailableBiometrics();
        if (mounted) {
          final msg = available.isEmpty
              ? 'Biometría no disponible: no hay huella/Face ID enrolada. Ve a Ajustes > Seguridad > Huella/Face ID y añade una, y configura PIN del sistema.'
              : 'Biometría no disponible en este dispositivo (isBiometricAvailable=false, enrolled=$available)';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
          );
        }
        return;
      }
      final (ok, code, msg) = await bio.authenticateDetailed();
      if (!ok) {
        if (!mounted) return;
        // Mapea códigos PlatformException de local_auth a mensaje útil
        String detail;
        switch (code) {
          case 'NotEnrolled':
          case 'NotAvailable':
            detail =
                'No hay biometría enrolada. Configura huella/Face ID en Ajustes del sistema.';
            break;
          case 'PasscodeNotSet':
            detail = 'Configura PIN/patrón del sistema para usar biometría.';
            break;
          case 'LockedOut':
          case 'PermanentlyLockedOut':
            detail =
                'Biometría bloqueada por intentos fallidos. Intenta con PIN del sistema o espera.';
            break;
          case 'UserCancel':
          case 'Canceled':
          case 'SystemCancel':
            detail = 'Autenticación cancelada';
            break;
          default:
            detail = code != null
                ? 'Autenticación fallida [$code] ${msg ?? ''}'.trim()
                : 'Autenticación cancelada o fallida';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail), duration: const Duration(seconds: 4)),
        );
        debugPrint(
          '[LoginPage] authenticateDetailed failed code=$code msg=$msg',
        );
        return;
      }
      final creds = await bio.getCredentials();
      final uid = creds['usuarioId'];
      final emp = creds['empresa'];
      if (uid != null && emp != null && uid.isNotEmpty && emp.isNotEmpty) {
        final id = int.tryParse(uid);
        if (id != null && mounted) {
          _goToDocumentos(id, emp);
          return;
        } else {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Credencial guardada no válida. Entra manualmente.',
                ),
              ),
            );
          return;
        }
      }
      // fallback a AuthStorage (SharedPreferences)
      final uid2 = await AuthStorage.getUsuarioId();
      final emp2 = await AuthStorage.getEmpresa();
      if (uid2 != null && emp2 != null && emp2.isNotEmpty && mounted) {
        _goToDocumentos(uid2, emp2);
        return;
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay sesión guardada. Entra con ID y empresa primero y guarda sesión para usar huella/Face ID',
            ),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Biometría error: $e')));
    }
  }

  Future<bool?> _preguntarActivarBiometria() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Acceso rápido y seguro'),
        content: Text(
          '¿Quieres entrar más rápido la próxima vez con $_biometriaLabel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, activar'),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarYEntrar() async {
    final userId = int.tryParse(_usuarioController.text);
    if (userId == null) return;
    if (_empresaSeleccionada == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una empresa')));
      return;
    }
    await AuthStorage.saveSession(
      usuarioId: userId,
      empresa: _empresaSeleccionada!.codigo,
    );
    if (!mounted) return;

    // Ofrecer activar biometría solo la primera vez, con consentimiento explícito (idea del usuario)
    try {
      final bio = BiometricService();
      final prefs = await SharedPreferences.getInstance();
      final yaOfrecido = prefs.getBool('biometria_ofrecida') ?? false;
      final yaHabilitado = await bio.hasSecureSession();
      final disponible = await bio.isBiometricAvailable();

      if (disponible && !yaHabilitado && !yaOfrecido) {
        final quiere = await _preguntarActivarBiometria();
        if (!mounted) return;
        if (quiere == true) {
          // Pedir huella/face para confirmar alta
          final (ok, code, msg) = await bio.authenticateDetailed();
          if (!mounted) return;
          if (ok) {
            await bio.saveCredentials(
              userId.toString(),
              _empresaSeleccionada!.codigo,
            );
            await prefs.setBool('biometria_ofrecida', true);
            await prefs.setBool('biometria_habilitada', true);
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ Biometría activada. La próxima vez podrás entrar con $_biometriaLabel',
                  ),
                ),
              );
          } else {
            String detail;
            switch (code) {
              case 'NotEnrolled':
              case 'NotAvailable':
                detail = 'No hay biometría enrolada en el sistema';
                break;
              case 'PasscodeNotSet':
                detail = 'Configura PIN del sistema primero';
                break;
              case 'UserCancel':
              case 'Canceled':
              case 'SystemCancel':
                detail = 'Activación cancelada. Puedes activarla más tarde';
                break;
              default:
                detail = code != null
                    ? 'No se pudo activar [$code]'
                    : 'No se pudo activar';
            }
            if (mounted)
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(detail)));
            await prefs.setBool('biometria_ofrecida', true);
          }
        } else if (quiere == false) {
          await prefs.setBool('biometria_ofrecida', true);
          await prefs.setBool('biometria_habilitada', false);
          // No guardamos credenciales seguras -> huella no se activará
          try {
            await bio.clear();
          } catch (_) {}
        }
      } else if (yaHabilitado) {
        // Ya estaba habilitado, actualizar credenciales por si cambió empresa
        try {
          await bio.saveCredentials(
            userId.toString(),
            _empresaSeleccionada!.codigo,
          );
        } catch (_) {}
      }
    } catch (_) {
      // Silencioso: no bloquea el login si falla el prompt biométrico
    }

    if (!mounted) return;
    _goToDocumentos(userId, _empresaSeleccionada!.codigo);
  }

  void _goToDocumentos(int userId, String empresa) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(usuarioId: userId, empresa: empresa),
      ),
    );
  }

  Future<void> _cargarEmpresas() async {
    try {
      final empresas = await EmpresaService.obtenerEmpresas();
      if (!mounted) return;
      setState(() {
        _empresas = empresas;
        if (empresas.isNotEmpty) {
          // Respetar empresa guardada si existe
          SharedPreferences.getInstance().then((prefs) {
            final guardada = prefs.getString('empresa');
            if (guardada != null && mounted) {
              final match = empresas
                  .where((e) => e.codigo == guardada)
                  .toList();
              setState(
                () => _empresaSeleccionada = match.isNotEmpty
                    ? match.first
                    : empresas.first,
              );
            } else if (mounted) {
              setState(() => _empresaSeleccionada = empresas.first);
            }
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al Cargar empresas: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      // resizeToAvoidBottomInset true por defecto; SingleChildScrollView evita bottom overflow con teclado
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Image.asset(
                      'assets/images/login_banner.png',
                      height: 160,
                      fit: BoxFit.contain,
                    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _usuarioController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ID de usuario',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Introduce tu ID'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _empresas.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    'Cargando empresas...',
                                    style: TextStyle(color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : DropdownButtonFormField<EmpresaDTO>(
                            value: _empresas.contains(_empresaSeleccionada)
                                ? _empresaSeleccionada
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Empresa',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            items: _empresas
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e.descripcion,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _empresaSeleccionada = v),
                            validator: (v) =>
                                v == null ? 'Selecciona una empresa' : null,
                          ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _guardarYEntrar();
                          }
                        },
                        child: const Text('Entrar'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.fingerprint),
                        label: Text(
                          'Entrar con $_biometriaLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: _loginBiometrico,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
