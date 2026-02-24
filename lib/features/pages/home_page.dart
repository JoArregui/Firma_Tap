import 'package:app_control_albaranes/features/pages/Configuration_page.dart';
import 'package:app_control_albaranes/features/pages/documentos_page.dart';
import 'package:app_control_albaranes/features/pages/login_page.dart';
import 'package:app_control_albaranes/features/pages/select_user_page.dart';
import 'package:flutter/material.dart';
import 'package:app_control_albaranes/features/pages/albaran_pendiente_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState(){
    super.initState();
    _usuarioId = widget.usuarioId;
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final nuevoId = prefs.getInt('usuarioId');
    if (nuevoId != null && nuevoId != _usuarioId) {
      setState(() {
        _usuarioId = nuevoId;
      });
    }
  }

  void _confirmarUsuario(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioGuardado = prefs.getInt('usuarioId') ?? widget.usuarioId;

    if (usuarioGuardado != widget.usuarioId) {
      final cambiar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Usuarios no activo'),
          content: const Text('¿Deseas cambiar de usuario para continuar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cambiar usuario'),
            ),
          ],
        ),
      );

      if (cambiar == true) {
        final nuevoId = await Navigator.push<int>(
          context,
          MaterialPageRoute(builder: (_) => const SelectUserPage()),
        );

        if (nuevoId != null) {
          await prefs.setInt('usuarioId', nuevoId);
          if (mounted) {
            setState(() => _usuarioId = nuevoId);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DocumentosPage(usuarioId: nuevoId, empresa: widget.empresa),
              ),
            );
          }
        }
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentosPage(usuarioId: usuarioGuardado, empresa: widget.empresa),
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú principal'),
        actions: [
          IconButton(
              icon:const Icon(Icons.logout),
              onPressed: () async{
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                );
              },
          )
        ],
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('Usuario: $_usuarioId',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text('Empresa: ${widget.empresa}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Lista de Opciones:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildMenuButton(
                    context,
                    title: 'Albaranes',
                    color: Colors.blue,
                    destination: const AlbaranPendientePage(),
                  ),
                  _buildMenuButton(
                    context,
                    title: 'Documentos',
                    color: Colors.deepPurple,
                      onPressed: () async {
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
                          Navigator.push(
                            context,
                            MaterialPageRoute( builder:
                                (_) => DocumentosPage( usuarioId: nuevoId, empresa: nuevaEmpresa,
                                ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _buildMenuButton(
                    context,
                    title: 'Configuración',
                    color: Colors.blueGrey,
                    destination: const ConfigurationPage(), // puedes reemplazarlo por una lógica de logout
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(
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
  }

}
