import 'dart:math';

import 'package:app_control_albaranes/features/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Services/empresa_service.dart';
import '../models/empresa_dto.dart';
import 'login_page.dart';

class ConfigurationPage extends StatefulWidget {
  const ConfigurationPage({super.key});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {

  static const String _passEmpresa = "1234";

  List<EmpresaDTO> _empresas = [];
  EmpresaDTO? _empresaSeleccionada;
  String _version = '';
  bool _cargandoEmpresas = true;



  @override
  void initState() {
    super.initState();
    _cargarEmpresas();
    _cargarVersion();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar empresas: $e')),
      );
    }finally{
      setState(() => _cargandoEmpresas = false);
    }
  }

  Future<void> _guardarEmpresa(EmpresaDTO empresa) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('empresa', empresa.codigo);
    final userId = prefs.getInt('usuarioId') ?? 0;

    setState(() {
      _empresaSeleccionada = empresa;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Empresa actualizada')),
    );

    // Navegar a la HomePage con animación
    await Future.delayed(const Duration(milliseconds: 300)); // da tiempo a mostrar el snackbar

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => HomePage(
          usuarioId: userId,
          empresa: empresa.codigo,
        ),
        transitionsBuilder: (_, animation, __, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOut;

          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
        (route) => false,
    );
  }

  /*
  Comentamos el metodo de cerrar sesion
  ya que comentan desde dirección que
  no es necesario
  Future<void> _logout() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );

    if (confirmar != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }*/

  Future<void> _cerrarApp() async {
    final confirmar = await showDialog<bool>(
        context: context, 
        builder: (_) => AlertDialog(
          title: const Text('Cerrar Aplicación'),
          content: const Text('¿Seguro que quieres cerrar la aplicación?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar')),
          ],
        ),
    );

    if(confirmar != true) return;

    SystemNavigator.pop();
  }

  Future<bool> _pedirPassword() async {
    final TextEditingController controller = TextEditingController();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cambiar empresa"),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: "Introduce la contraseña",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, controller.text == _passEmpresa);
            },
            child: const Text("Aceptar"),
          ),
        ],
      ),
    );

    return resultado ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController _endpointController = TextEditingController(
      text: 'https://pirineosapi.ecomputer.es/'
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Color.fromARGB(255,0,47,108),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: SizedBox(
                width: 450, // Ajusta este valor según el ancho deseado
                child: TextFormField(
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
              ),
            ),
            const SizedBox(height: 30, width: 15),
            const Text('Selecciona tu empresa:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            _cargandoEmpresas
                ? const CircularProgressIndicator()
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOut)
                : DropdownButton<EmpresaDTO>(
              value: _empresas.contains(_empresaSeleccionada) ? _empresaSeleccionada : null,
              hint: const Text('Selecciona una empresa...'),
              items: _empresas.map((e) {
                return DropdownMenuItem<EmpresaDTO>(
                  value: e,
                  child: Text(e.descripcion),
                );
              }).toList(),
                onChanged: (value) async {
                  if (value == null) return;

                  // Si no había empresa seleccionada antes, permitir directamente
                  if (_empresaSeleccionada == null) {
                    _guardarEmpresa(value);
                    return;
                  }

                  // Si ya había empresa, pedir contraseña
                  final ok = await _pedirPassword();
                  if (ok) {
                    _guardarEmpresa(value);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Contraseña incorrecta")),
                    );
                  }
                },
            ),
            const SizedBox(height: 30),
            Text('Versión de la app: $_version', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _cerrarApp,
              icon: const Icon(Icons.close),
              label: const Text('Cerrar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            )
          ],
        ),
      ),
    );
  }
}
