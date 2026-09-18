import 'package:flutter/material.dart';

class HomeDrawer extends StatelessWidget {
  final int usuarioId;
  final String descripcionEmpresa;
  final VoidCallback onConfig;
  final VoidCallback onCloseApp;

  const HomeDrawer({
    super.key,
    required this.usuarioId,
    required this.descripcionEmpresa,
    required this.onConfig,
    required this.onCloseApp,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.indigo),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              ),
          ),

          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuración'),
            onTap: () {
              Navigator.pop(context);
              onConfig();
            },
          ),
        ],
      ),
    );
  }
}
