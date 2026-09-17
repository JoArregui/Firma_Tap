import 'package:app_control_albaranes/core/auth/biometric_service.dart';
import 'package:app_control_albaranes/core/storage/auth_storage.dart';
import 'package:app_control_albaranes/features/Services/empresa_service.dart';
import 'package:app_control_albaranes/features/models/empresa_dto.dart';
import 'package:app_control_albaranes/features/pages/home_page.dart';
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

  @override
  void initState(){
    super.initState();
    _checkLogin();
    _cargarEmpresas();
  }

  Future<void> _checkLogin() async{
    final userId = await AuthStorage.getUsuarioId();
    final empresa = await AuthStorage.getEmpresa();
    if(userId != null && empresa != null && empresa.isNotEmpty){
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometría no disponible')));
        return;
      }
      final ok = await bio.authenticate();
      if (!ok) return;
      final creds = await bio.getCredentials();
      final uid = creds['usuarioId'];
      final emp = creds['empresa'];
      if (uid != null && emp != null) {
        final id = int.tryParse(uid);
        if (id != null && mounted) _goToDocumentos(id, emp);
      } else {
        // fallback a AuthStorage
        final uid2 = await AuthStorage.getUsuarioId();
        final emp2 = await AuthStorage.getEmpresa();
        if (uid2 != null && emp2 != null && mounted) _goToDocumentos(uid2, emp2);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Biometría error: $e')));
    }
  }

  Future<void> _guardarYEntrar() async{
    final userId = int.tryParse(_usuarioController.text);
    if(userId == null) return;
    if (_empresaSeleccionada == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una empresa')),
      );
      return;
    }
    await AuthStorage.saveSession(usuarioId: userId, empresa: _empresaSeleccionada!.codigo);
    try { await BiometricService().saveCredentials(userId.toString(), _empresaSeleccionada!.codigo); } catch (_) {}
    if (!mounted) return;
    _goToDocumentos(userId, _empresaSeleccionada!.codigo);
  }

  void _goToDocumentos(int userId, String empresa){
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => HomePage(usuarioId: userId, empresa: empresa),
        ),
    );
  }

  Future<void> _cargarEmpresas() async{
    try{
      final empresas = await EmpresaService.obtenerEmpresas();
      if (!mounted) return;
      setState(() {
        _empresas = empresas;
        if (empresas.isNotEmpty) {
          // Respetar empresa guardada si existe
          SharedPreferences.getInstance().then((prefs) {
            final guardada = prefs.getString('empresa');
            if (guardada != null && mounted) {
              final match = empresas.where((e) => e.codigo == guardada).toList();
              setState(() => _empresaSeleccionada = match.isNotEmpty ? match.first : empresas.first);
            } else if (mounted) {
              setState(() => _empresaSeleccionada = empresas.first);
            }
          });
        }
      });
    }catch(e){
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al Cargar empresas: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    Image.asset(
                      'assets/images/login_banner.png',
                      height: 200,
                      fit: BoxFit.contain,
                    )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .slideY(begin: -0.2),
                    SizedBox(height: 10),
                    SizedBox(
                      width: 420,
                      child: TextFormField(
                        controller: _usuarioController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ID de usuario',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (value) =>
                        value == null || value.isEmpty ? 'Introduce tu ID' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 420,
                      child: _empresas.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(width: 12),
                                  Text('Cargando empresas...', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<EmpresaDTO>(
                              value: _empresas.contains(_empresaSeleccionada) ? _empresaSeleccionada : null,
                              decoration: const InputDecoration(
                                labelText: 'Empresa',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _empresas.map((e) => DropdownMenuItem(value: e, child: Text(e.descripcion))).toList(),
                              onChanged: (v) => setState(() => _empresaSeleccionada = v),
                              validator: (v) => v == null ? 'Selecciona una empresa' : null,
                            ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(width: 420, child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _guardarYEntrar();
                        }
                        },
                      child: const Text('Entrar'),
                    )),
                    const SizedBox(height: 12),
                    SizedBox(width: 420, child: OutlinedButton.icon(
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Entrar con huella / Face ID'),
                      onPressed: _loginBiometrico,
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
