import 'package:app_control_albaranes/features/pages/documentos_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectUserPage extends StatefulWidget {
  const SelectUserPage({super.key});

  @override
  State<SelectUserPage> createState() => _SelectUserPageState();
}

class _SelectUserPageState extends State<SelectUserPage> {
  final TextEditingController _controller = TextEditingController();

  void _confirmar() async {
    final id = int.tryParse(_controller.text);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un ID válido')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final empresa = prefs.getString('empresa');
    await prefs.setInt('usuarioId', id);


    Navigator.pop(context, {
      'usuarioId': id,
      'empresa': empresa, // Puedes hacer esto dinámico si lo deseas
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validar Usuario')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Introduce el ID de usuario:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'ID de usuario',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _confirmar,
              icon: const Icon(Icons.check),
              label: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }
}
