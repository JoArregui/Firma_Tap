import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ConfigurationPage extends StatelessWidget {
  const ConfigurationPage({super.key});

  Future<String> _getVersion() async {
    final info = await PackageInfo.fromPlatform();
    return 'Versión ${info.version} (Build ${info.buildNumber})';
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
        child: FutureBuilder<String>(
          future: _getVersion(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.build_circle, size: 80, color: Colors.grey),
                const SizedBox(height: 20),
                const Text(
                  'Página en mantenimiento',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Estamos trabajando en esta sección.\nVuelve pronto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                Text(
                  snapshot.data ?? '',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
