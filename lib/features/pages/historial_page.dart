import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/storage/history_service.dart';
import '../../core/share/share_service.dart';

class HistorialPage extends StatefulWidget {
  const HistorialPage({super.key});
  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  List<HistorialEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await HistoryService.init();
    final list = await HistoryService.getAll();
    if (mounted) setState(() { _items = list; _loading = false; });
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Borrar historial'), content: const Text('¿Seguro?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar'))]));
    if (ok == true) { await HistoryService.clear(); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial'), backgroundColor: const Color(0xFF002F6C), foregroundColor: Colors.white, actions: [IconButton(onPressed: _clear, icon: const Icon(Icons.delete)), IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _items.isEmpty ? const Center(child: Text('Sin firmas aún')) : ListView.builder(itemCount: _items.length, itemBuilder: (_, i) {
        final e = _items[i];
        return Card(child: ListTile(title: Text('${e.tipoDocumento} Nº ${e.numero}'), subtitle: Text('${e.empresa} • ${DateFormat('dd/MM/yyyy HH:mm').format(e.fecha)} • hash ${e.hash.substring(0, 8)}'), trailing: IconButton(icon: const Icon(Icons.share), onPressed: () async {
          // Compartir como texto (no tenemos PDF, compartimos hash)
          await ShareService().shareText('Firma ${e.numero} ${e.tipoDocumento} ${e.fecha} hash ${e.hash}');
        })));
      }),
    );
  }
}
