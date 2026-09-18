import 'package:firma_tap/features/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/empresa_service.dart';
import '../models/empresa_dto.dart';

class ConfigurationPage extends StatefulWidget {
  const ConfigurationPage({super.key});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {

  static const String _passEmpresa = '1234';

  List<EmpresaDTO> _empresas = [];
  EmpresaDTO? _empresaSeleccionada;
  String _version = '';
  bool _cargandoEmpresas = true;
  late final TextEditingController _endpointController;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(text: 'https://pirineosapi.ecomputer.es/');
    _cargarEmpresas();
    _cargarVersion();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    super.dispose();
  }

  Future<void> _cargarVersion() async{
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version}+${info.buildNumber}';
    });
  }

  Future<void> _cargarEmpresas() async{
    setState(() => _cargandoEmpresas = true);

    try{
      final prefs = await SharedPreferences.getInstance();
      final codGuardado = prefs.getString('empresa');

      final empresas = await EmpresaService.obtenerEmpresas();
      EmpresaDTO? empresaSeleccionada;

      if(codGuardado != null){
        final encontrada = empresas.where(
            (e) => e.codigo == codGuardado).toList();
        if(encontrada.isNotEmpty){
          empresaSeleccionada = encontrada.first;
        }
      }

      setState(() {
        _empresas = empresas;
        _empresaSeleccionada = empresaSeleccionada;
      });
    }catch(e){
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar empresas: $e')),
      );
    }finally{
      setState(() => _cargandoEmpresas = false);
    }
  }

  Future<void> _guardarEmpresa(EmpresaDTO empresa) async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('empresa', empresa.codigo);
    final userId = prefs.getInt('usuarioId') ?? 0;

    setState(() {
      _empresaSeleccionada = empresa;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Empresa actualizada')),
    );

    if (!mounted) return;

    // Navegar a la HomePage con animación
    await Future.delayed(const Duration(milliseconds: 300)); // da tiempo a mostrar el snackbar

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(
          usuarioId: userId,
          empresa: empresa.codigo,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<bool> _pedirPassword() async {
    final TextEditingController controller = TextEditingController();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cambiar empresa'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Introduce la contraseña',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, controller.text == _passEmpresa);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    return resultado ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: const Color.fromARGB(255,0,47,108),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.settings, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _endpointController,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Enlace',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  const Text('Selecciona tu empresa:', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  _cargandoEmpresas
                      ? const CircularProgressIndicator()
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(begin: Offset(0.8, 0.8), curve: Curves.easeOut)
                      : DropdownButton<EmpresaDTO>(
                    value: _empresas.contains(_empresaSeleccionada) ? _empresaSeleccionada : null,
                    isExpanded: true,
                    hint: const Text('Selecciona una empresa...', overflow: TextOverflow.ellipsis),
                    items: _empresas.map((e) {
                      return DropdownMenuItem<EmpresaDTO>(
                        value: e,
                        child: Text(e.descripcion, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                      onChanged: (value) async {
                        if (value == null) return;

                        if (_empresaSeleccionada == null) {
                          _guardarEmpresa(value);
                          return;
                        }

                        final ok = await _pedirPassword();
                        if (!mounted) return;
                        if (ok) {
                          _guardarEmpresa(value);
                        } else {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Contraseña incorrecta')),
                          );
                        }
                      },
                  ),
                  const SizedBox(height: 30),
                  Text('Versión de la app: $_version', style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
