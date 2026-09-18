import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectUserPage extends StatefulWidget {
  const SelectUserPage({super.key});

  @override
  State<SelectUserPage> createState() => _SelectUserPageState();
}

class _SelectUserPageState extends State<SelectUserPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

  if (!mounted) return; // <-- guard tras los await

  Navigator.pop(context, {
    'usuarioId': id,
    'empresa': empresa,
  });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validar Usuario')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Introduce el ID de usuario:', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _confirmar,
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
