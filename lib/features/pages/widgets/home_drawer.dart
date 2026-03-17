import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.indigo),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_circle, size: 60, color: Colors.white),
                const SizedBox(height: 10),
                Text("Usuario: $usuarioId",
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                Text("Empresa: $descripcionEmpresa",
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Configuración"),
            onTap: () {
              Navigator.pop(context);
              onConfig();
            },
          ),

          ListTile(
            leading: const Icon(Icons.close),
            title: const Text("Cerrar aplicación"),
            onTap: () {
              Navigator.pop(context);
              onCloseApp();
            },
          ),
        ],
      ),
    );
  }
}
