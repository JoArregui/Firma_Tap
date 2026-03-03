import 'package:app_control_albaranes/features/Services/empresa_service.dart';
import 'package:app_control_albaranes/features/models/empresa_dto.dart';
import 'package:app_control_albaranes/features/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'documentos_page.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('usuarioId');
    final empresa = prefs.getString('empresa');
    if(userId != null && empresa != null){
      _goToDocumentos(userId, empresa);
    }
  }

  Future<void> _guardarYEntrar() async{
    final userId = int.tryParse(_usuarioController.text);
    if(userId != null){
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('usuarioId', userId);
      _goToDocumentos(userId, '');
    }
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
      setState(() {
        _empresas = empresas;
        _empresaSeleccionada = empresas.first;
      });
    }catch(e){
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
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _guardarYEntrar();
                        }
                        },
                      child: const Text('Entrar'),
                    ),
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
