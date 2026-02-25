import 'dart:math';

import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _cargarEmpresas();
  }

  Future<void> _cargarEmpresas() async{
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
            const Text('Selecciona tu empresa:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            DropdownButton<EmpresaDTO>(
              value: _empresaSeleccionada,
              items: _empresas.map((e){
               return DropdownMenuItem<EmpresaDTO>(
                 value: e,
                 child: Text(e.descripcion),
               );
              }).toList(),
              onChanged: (value) {
                if (value != null) _guardarEmpresa(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
