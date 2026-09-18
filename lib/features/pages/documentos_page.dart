import 'package:firma_tap/features/pages/documento_pdf_page.dart';
import 'package:firma_tap/features/pages/firma_documento_page.dart';
import 'package:firma_tap/features/pages/lote_firma_page.dart';
import 'package:flutter/material.dart';
import '../repositories/albaran_repository.dart';
import '../models/documento_dto.dart';

class DocumentosPage extends StatefulWidget {
  final int usuarioId;
  final String empresa;

  const DocumentosPage({
    super.key,
    required this.usuarioId,
    required this.empresa,
  });

  @override
  State<DocumentosPage> createState() => _DocumentosPageState();
}

class _DocumentosPageState extends State<DocumentosPage> {
  late Future<List<DocumentoDto>> futureDocumentos;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _cargarDocumentos();
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _cargarDocumentos() {
    setState(() {
      futureDocumentos = AlbaranRepository().obtenerDocumento(
        widget.usuarioId,
        widget.empresa,
      );
      _selected.clear();
    });
  }

  List<DocumentoDto> _filtrar(List<DocumentoDto> list) {
    if (_query.isEmpty) return list;
    return list
        .where(
          (d) => '${d.numero} ${d.tipoDocumento} ${d.total}'
              .toLowerCase()
              .contains(_query),
        )
        .toList();
  }

  bool _esDocVacio(DocumentoDto doc) {
    return doc.id == 0 &&
        (doc.codigoEmpresa == 'null' || doc.codigoEmpresa == null) &&
        (doc.tipoDocumento == 'null' || doc.tipoDocumento == null) &&
        doc.numero == 0;
  }

  Widget _buildSinDocumentos() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No hay documentos disponibles.'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _cargarDocumentos,
            icon: const Icon(Icons.refresh),
            label: const Text('Recargar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos pendientes'),
        backgroundColor: const Color(0xFF002F6C),
        foregroundColor: Colors.white,
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.playlist_add_check),
              tooltip: 'Firmar lote ${_selected.length}',
              onPressed: () => _firmarLote(),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por número, tipo o total...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<DocumentoDto>>(
              future: futureDocumentos,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Error al cargar documentos:\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _cargarDocumentos,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildSinDocumentos();
                }

                final documentos = _filtrar(snapshot.data!);
                if (documentos.isEmpty) return _buildSinDocumentos();
                if (documentos.length == 1 && _esDocVacio(documentos.first)) {
                  return const Center(
                    child: Text('No hay Documentos disponibles.'),
                  );
                }

                return ListView.builder(
                  itemCount: documentos.length,
                  itemBuilder: (context, index) {
                    final doc = documentos[index];
                    final sel = _selected.contains(doc.numero);
                    return Card(
                      color: sel ? Colors.blue.shade50 : null,
                      child: ListTile(
                        leading: Checkbox(
                          value: sel,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(doc.numero);
                            } else {
                              _selected.remove(doc.numero);
                            }
                          }),
                        ),
                        title: Text(
                          '${doc.tipoDocumento ?? 'Documento'} Nº ${doc.numero}',
                        ),
                        subtitle: Text(
                          'Total: ${doc.total.toStringAsFixed(2)} € • ${doc.codigoEmpresa}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf),
                              tooltip: 'Ver PDF',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DocumentoPdfPage(documento: doc),
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_circle_right),
                          ],
                        ),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FirmaDocumentoPage(documento: doc),
                            ),
                          );
                          if (result == true) {
                            _cargarDocumentos();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '✅ Documento firmado correctamente',
                                  ),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                        onLongPress: () => setState(() {
                          if (sel) {
                            _selected.remove(doc.numero);
                          } else {
                            _selected.add(doc.numero);
                          }
                        }),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _firmarLote() async {
    final all = await futureDocumentos;
    if (!mounted) return; // <-- guard tras el primer await

    final toSign = all.where((d) => _selected.contains(d.numero)).toList();
    if (toSign.isEmpty) return;
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LoteFirmaPage(documentos: toSign, empresa: widget.empresa),
      ),
    );
    if (!mounted) return;
    if (res == true) {
      _cargarDocumentos();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Lote firmado')));
    }
  }
}