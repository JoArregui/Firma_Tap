import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/offline/queue_service.dart';
import '../../core/storage/history_service.dart';
import '../../core/media/foto_geo_service.dart';
import '../services/firma_service.dart';
import '../models/documento_dto.dart';

/// Firma en lote: swipe horizontal entre documentos con una sola firma reutilizable
class LoteFirmaPage extends StatefulWidget {
  final List<DocumentoDto> documentos;
  final String empresa;
  const LoteFirmaPage({super.key, required this.documentos, required this.empresa});

  @override
  State<LoteFirmaPage> createState() => _LoteFirmaPageState();
}

class _LoteFirmaPageState extends State<LoteFirmaPage> {
  final SignatureController _ctrl = SignatureController(penStrokeWidth: 3, penColor: Colors.black, exportBackgroundColor: Colors.white);
  final PageController _page = PageController();
  final FotoGeoService _fotoGeo = FotoGeoService();
  int _idx = 0;
  bool _saving = false;
  String? _fotoPath;
  double _lat = 0, _lng = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    _page.dispose();
    super.dispose();
  }

  Future<void> _firmarActual() async {
    if (_ctrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firma primero')));
      return;
    }
    setState(() => _saving = true);
    try {
      final jpg = await FirmaService.convertirFirmaABytesJpg(controller: _ctrl);
      final doc = widget.documentos[_idx];
      // Intentar foto/geo opcional (no bloqueante)
      try {
        if (_fotoPath == null) {
          // No pedimos foto automáticamente; usuario puede pulsar botón foto
        }
        final pos = await _fotoGeo.getCurrentLocation();
        _lat = pos.latitude;
        _lng = pos.longitude;
      } catch (_) {
        _lat = 0; _lng = 0;
      }
      try {
        await FirmaService.enviarFirma(jpgBytes: jpg, codigoEmpresa: doc.codigoEmpresa ?? widget.empresa, tipoDocumento: doc.tipoDocumento ?? 'ALB', numero: doc.numero, usuario: doc.usuario.toString());
        await HistoryService.addWithBytes(numero: doc.numero, tipoDocumento: doc.tipoDocumento ?? '-', empresa: doc.codigoEmpresa ?? widget.empresa, usuario: doc.usuario.toString(), jpgBytes: jpg, lat: _lat, lng: _lng);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${doc.numero} firmado')));
      } catch (e) {
        // Offline: encola
        await QueueService.enqueue(FirmaPendiente.fromBytes(codigoEmpresa: doc.codigoEmpresa ?? widget.empresa, tipoDocumento: doc.tipoDocumento ?? 'ALB', numero: doc.numero, usuario: doc.usuario.toString(), jpgBytesRaw: jpg, fotoPath: _fotoPath, lat: _lat, lng: _lng));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📡 Sin conexión: encolado ${doc.numero}')));
      }
      // Avanzar o cerrar
      if (_idx < widget.documentos.length - 1) {
        _page.nextPage(duration: 300.ms, curve: Curves.easeOut);
        _ctrl.clear();
      } else {
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickFoto() async {
    try {
      final x = await _fotoGeo.pickPhoto();
      if (x != null && mounted) setState(() => _fotoPath = x.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Foto: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.documentos.length;
    return Scaffold(
      appBar: AppBar(title: Text('Lote $total documentos'), backgroundColor: const Color(0xFF002F6C), foregroundColor: Colors.white),
      body: Column(
        children: [
          LinearProgressIndicator(value: (total == 0) ? 0 : (_idx + 1) / total),
          Padding(padding: const EdgeInsets.all(8), child: Text('${_idx + 1} / $total', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: PageView.builder(
              controller: _page,
              onPageChanged: (i) => setState(() => _idx = i),
              itemCount: total,
              itemBuilder: (_, i) {
                final d = widget.documentos[i];
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          FittedBox(fit: BoxFit.scaleDown, child: Text('${d.tipoDocumento} Nº ${d.numero}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          Text('Total ${d.total.toStringAsFixed(2)} €', overflow: TextOverflow.ellipsis),
                          if (_fotoPath != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('📸 Foto: ${_fotoPath!.split('/').last}', style: const TextStyle(color: Colors.green, fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1)),
                          const SizedBox(height: 12),
                          Expanded(child: Container(decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(8), color: Colors.grey[200]), child: Signature(controller: _ctrl, backgroundColor: Colors.white))),
                          const SizedBox(height: 8),
                          // Wrap evita bottom overflowed by pixels en pantallas estrechas
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(onPressed: _ctrl.clear, icon: const Icon(Icons.clear), label: const Text('Borrar')),
                              OutlinedButton.icon(onPressed: _pickFoto, icon: const Icon(Icons.camera_alt), label: const Text('Foto')),
                              ElevatedButton.icon(onPressed: _saving ? null : _firmarActual, icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check), label: Text(i == total - 1 ? 'Firmar y cerrar' : 'Firmar y siguiente', overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
