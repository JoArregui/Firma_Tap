import 'package:app_control_albaranes/features/pages/Configuration_page.dart';
import 'package:app_control_albaranes/features/pages/documentos_page.dart';
import 'package:app_control_albaranes/features/pages/login_page.dart';
import 'package:app_control_albaranes/features/pages/select_user_page.dart';
import 'package:app_control_albaranes/features/pages/widgets/empresa_card.dart';
import 'package:app_control_albaranes/features/pages/widgets/home_card.dart';
import 'package:app_control_albaranes/features/pages/widgets/home_drawer.dart';
import 'package:app_control_albaranes/features/pages/widgets/home_navigation_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/animated_routes.dart';
import '../Services/empresa_service.dart';
import '../models/empresa_dto.dart';

class HomePage extends StatefulWidget {
  final int usuarioId;
  final String empresa;

  const HomePage({
    super.key,
    required this.usuarioId,
    required this.empresa});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _usuarioId;
  late String _empresa;
  String _Descripcion = '';

  @override
  void initState(){
    super.initState();
    _usuarioId = widget.usuarioId;
    _empresa = widget.empresa;
    _cargarDatos();
    _cargarDescripcionEmpresa();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final nuevoId = prefs.getInt('usuarioId');
    final nuevaEmpresa = prefs.getString('empresa');

    setState(() {
      if (nuevoId != null) _usuarioId = nuevoId;
      if(nuevaEmpresa != null) _empresa = nuevaEmpresa;
    });
  }

  Future<void> _cargarDescripcionEmpresa() async {
    final prefs = await SharedPreferences.getInstance();
    final codigo = prefs.getString('empresa');

    if (codigo != null) {
      try {
        final empresas = await EmpresaService.obtenerEmpresas();
        final empresa = empresas.firstWhere(
              (e) => e.codigo == codigo,
          orElse: () => EmpresaDTO(codigo: codigo, descripcion: codigo),
        );
        setState(() {
          _Descripcion = empresa.descripcion;
        });
      } catch (e) {
        setState(() {
          _Descripcion = codigo; // fallback si falla
        });
      }
    }
  }

  Future<void> _logout() async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
    );
  }

  Future<void> _goToPendientes() async{
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const SelectUserPage()),
    );
    if (resultado != null) {
      final nuevoId = resultado['usuarioId'] as int;
      final nuevaEmpresa = resultado['empresa'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('usuarioId', nuevoId);
      await prefs.setString('empresa', nuevaEmpresa);

      if (context.mounted) {
        navegarAnimado(
          context,
          DocumentosPage(usuarioId: nuevoId, empresa: nuevaEmpresa),
        );

      }
    }
  }

  Future<void> _gotoConfig() async {
    await navegarAnimado(context, const ConfigurationPage());
    if (context.mounted) {
      _cargarDatos();
      _cargarDescripcionEmpresa();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú principal'),
        /*actions: [
          IconButton(
            icon:const Icon(Icons.logout),
            onPressed: _logout,
          )
        ],*/
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        automaticallyImplyActions: !isTablet, //ocualtamos el icono de menu en tablets
      ),
      
      //Agregamos un drawer lateral solo moviles
      drawer: isTablet
          ? null
          : HomeDrawer(
        usuarioId: _usuarioId,
        descripcionEmpresa: _Descripcion,
        onConfig: _gotoConfig,
        onCloseApp: () => SystemNavigator.pop(),
      ),

      body: Row(
        children: [
          //NavigationRail SOLO en tablets
          if (isTablet)
            HomeNavigationRail(
              onSelect: (index) {
                if (index == 0) _goToPendientes();
                if (index == 1) _gotoConfig();
                if (index == 2) SystemNavigator.pop();
                },
            ),
          //Aqui ponemos el contenido principal del homePage
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const Icon(Icons.business_center, size: 48, color: Colors.indigo),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text( '$_Descripcion', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold , color: Colors.black)),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
                  const SizedBox(height: 30),
                  const Text('Opciones disponibles:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: isTablet ? 3 :2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      children: [
                        HomeCard(
                            icon: Icons.description,
                            label: 'Firmas Pendientes',
                            color: Colors.deepPurple,
                            onTap: _goToPendientes),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /*Widget _buildMenuButton(
      BuildContext context, {
        required String title,
        required Color color,
        Widget? destination,
        VoidCallback? onPressed,
      }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 5,
      ),
      onPressed: onPressed ??
              () {
            if (destination != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => destination),
              );
            }
          },
      child: Center(
        child: Text(
          title,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }*/

}
