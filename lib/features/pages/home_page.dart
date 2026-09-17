import 'package:app_control_albaranes/core/storage/auth_storage.dart';
import 'package:app_control_albaranes/features/pages/Configuration_page.dart';
import 'package:app_control_albaranes/features/pages/analytics_page.dart';
import 'package:app_control_albaranes/features/pages/documentos_page.dart';
import 'package:app_control_albaranes/features/pages/historial_page.dart';
import 'package:app_control_albaranes/features/pages/login_page.dart';
import 'package:app_control_albaranes/features/pages/roles_page.dart';
import 'package:app_control_albaranes/features/pages/select_user_page.dart';
import 'package:app_control_albaranes/features/pages/widgets/home_card.dart';
import 'package:app_control_albaranes/features/pages/widgets/home_navigation_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    final nuevoId = await AuthStorage.getUsuarioId();
    final nuevaEmpresa = await AuthStorage.getEmpresa();

    if (!mounted) return;
    setState(() {
      if (nuevoId != null) _usuarioId = nuevoId;
      if(nuevaEmpresa != null) _empresa = nuevaEmpresa;
    });
  }

  Future<void> _cargarDescripcionEmpresa() async {
    final codigo = await AuthStorage.getEmpresa();

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
    await AuthStorage.clear();
    if (!mounted) return;
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
      await AuthStorage.saveSession(usuarioId: nuevoId, empresa: nuevaEmpresa);

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
        leading: IconButton(
            onPressed: _gotoConfig,
            icon: const Icon(Icons.settings),
        ),
        actions: [
          IconButton(
            icon:const Icon(Icons.logout),
            onPressed: SystemNavigator.pop,
          )
        ],
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 0, 47, 108),
        foregroundColor: Colors.white,
        automaticallyImplyActions: !isTablet, //ocualtamos el icono de menu en tablets
      ),
      
      //Agregamos un drawer lateral solo moviles
      /*drawer: isTablet
          ? null
          : HomeDrawer(
        usuarioId: _usuarioId,
        descripcionEmpresa: _Descripcion,
        onConfig: _gotoConfig,
        onCloseApp: () => SystemNavigator.pop(),
      ),*/

      body: Row(
        children: [
          //NavigationRail SOLO en tablets
          if (isTablet)
            HomeNavigationRail(
              onSelect: (index) {
                if (index == 0) _goToPendientes();
                if (index == 1) _gotoConfig();
                if (index == 99) SystemNavigator.pop();
                },
            ),
          // 👉 Aquí va la línea vertical
          if (isTablet)
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: Colors.grey,
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
                          const Icon(Icons.business_center, size: 48, color: Color.fromARGB(255, 0, 47, 108)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text( '$_Descripcion', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold , color: Colors.black)),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
                  const SizedBox(height: 30),
                  const SizedBox(height: 20),
                    Expanded(
                    child: GridView.count(
                      crossAxisCount: isTablet ? 2 : 1,
                      childAspectRatio: isTablet ? 3.2 : 3.5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        HomeCard(icon: Icons.description, label: 'Firmas Pendientes', color: Colors.grey.shade100, onTap: _goToPendientes),
                        HomeCard(icon: Icons.picture_as_pdf, label: 'Vista PDF', color: Colors.blue.shade50, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentosPage(usuarioId: _usuarioId, empresa: _empresa)))),
                        HomeCard(icon: Icons.history, label: 'Historial', color: Colors.orange.shade50, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistorialPage()))),
                        HomeCard(icon: Icons.analytics, label: 'Analítica', color: Colors.green.shade50, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsPage()))),
                        HomeCard(icon: Icons.group, label: 'Roles', color: Colors.purple.shade50, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RolesPage()))),
                        HomeCard(icon: Icons.share, label: 'Compartir', color: Colors.teal.shade50, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usa el botón compartir en PDF/Historial')))),
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

  Widget _buildMenuCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 200, // ← altura reducida
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: color,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 500.ms)
          .slideY(begin: 0.2)
          .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOut),
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
