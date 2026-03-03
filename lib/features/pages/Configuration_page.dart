import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Services/empresa_service.dart';
import '../models/empresa_dto.dart';

class ConfigurationPage extends StatefulWidget {
  const ConfigurationPage({super.key});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
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
      EmpresaDTO empresaSeleccionada = empresas.first;

      if(codGuardado != null){
        final encontrada = empresas.firstWhere(
            (e) => e.codigo == codGuardado,
        orElse: () => empresaSeleccionada,
        );
        empresaSeleccionada = encontrada;
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
    setState(() {
      _empresaSeleccionada = empresa;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Empresa actualizada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController _endpointController = TextEditingController(
      text: 'https://pirineosapi.ecomputer.es/'
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.blue,
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
              value: _empresaSeleccionada,
              items: _empresas.map((e) {
                return DropdownMenuItem<EmpresaDTO>(
                  value: e,
                  child: Text(e.descripcion),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) _guardarEmpresa(value);
              },

            ),
            const SizedBox(height: 30),
            Text('Versión de la app: $_version', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
