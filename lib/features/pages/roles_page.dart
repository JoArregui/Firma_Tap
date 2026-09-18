import 'package:flutter/material.dart';
import '../../core/storage/auth_storage.dart';
import '../services/empresa_service.dart';
import '../models/empresa_dto.dart';

class RolesPage extends StatefulWidget {
  const RolesPage({super.key});
  @override
  State<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends State<RolesPage> {
  List<EmpresaDTO> _empresas = [];
  String? _rol; // admin, supervisor, usuario
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final emp = await EmpresaService.obtenerEmpresas();
      if (mounted) setState(() { _empresas = emp; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
    await AuthStorage.getEmpresa(); // reutiliza key empresa como rol simple
    // Simula rol guardado en prefs key rol
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roles y delegación'), backgroundColor: const Color(0xFF002F6C), foregroundColor: Colors.white),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Selecciona rol de supervisor para delegar firma:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: _rol, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Rol'), items: const [DropdownMenuItem(value: 'usuario', child: Text('Usuario')), DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')), DropdownMenuItem(value: 'admin', child: Text('Admin'))], onChanged: (v) => setState(() => _rol = v)),
          const SizedBox(height: 20),
          const Text('Empresas disponibles para delegar:'),
          ..._empresas.map((e) => Card(child: ListTile(title: Text(e.descripcion), subtitle: Text(e.codigo), trailing: const Icon(Icons.arrow_forward)))),
          const SizedBox(height: 20),
          ElevatedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delegación guardada (simulada)'))), icon: const Icon(Icons.check), label: const Text('Guardar delegación')),
        ],
      ),
    );
  }
}
