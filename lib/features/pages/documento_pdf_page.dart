import 'dart:io';

import 'package:app_control_albaranes/core/constants/api_constants.dart';
import 'package:app_control_albaranes/core/share/share_service.dart';
import 'package:app_control_albaranes/features/models/documento_dto.dart';
import 'package:app_control_albaranes/features/pages/firma_documento_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

/// Página de preview de PDF usando `pdfx` [PdfViewPinch] con pinch-zoom.
///
/// Recibe [DocumentoDto] o [pdfUrl] (String).
/// - Si [pdfUrl] se proporciona, se usa directamente.
/// - Si solo [documento] se proporciona, se construye la URL a partir de [ApiConstants.documentoBaseUrl].
///
/// Descarga el PDF con `http` + `path_provider` (temp), lo muestra con pinch-zoom,
/// toolbar con compartir (`share_plus`) y botón "Firmar".
/// Maneja estados de loading/error y chequea `mounted` antes de `setState`.
class DocumentoPdfPage extends StatefulWidget {
  final DocumentoDto? documento;
  final String? pdfUrl;
  final String? title;

  const DocumentoPdfPage({
    super.key,
    this.documento,
    this.pdfUrl,
    this.title,
  }) : assert(
          documento != null || (pdfUrl != null && pdfUrl != ''),
          'Debe proporcionar documento o pdfUrl',
        );

  @override
  State<DocumentoPdfPage> createState() => _DocumentoPdfPageState();
}

class _DocumentoPdfPageState extends State<DocumentoPdfPage> {
  bool _isLoading = true;
  String? _error;
  File? _pdfFile;
  PdfControllerPinch? _pdfController;

  final ShareService _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    // PdfControllerPinch no tiene dispose explícito, pero limpiamos referencia
    _pdfController = null;
    super.dispose();
  }

  String _resolvePdfUrl() {
    if (widget.pdfUrl != null && widget.pdfUrl!.trim().isNotEmpty) {
      debugPrint('[DocumentoPdfPage] usando pdfUrl directo: ${widget.pdfUrl}');
      return widget.pdfUrl!.trim();
    }

    final doc = widget.documento!;
    // Construcción query-string compatible con backend .NET
    // Ej: https://pirineosapi.ecomputer.es/DocumentoAFirmar/GetPdf?CodigoEmpresa=X&TipoDocumento=Y&Numero=Z
    // Se mantiene robusta con encode.
    final base = ApiConstants.documentoBaseUrl;
    final codigoEmpresa = Uri.encodeComponent(doc.codigoEmpresa ?? '');
    final tipoDocumento = Uri.encodeComponent(doc.tipoDocumento ?? '');
    final numero = doc.numero.toString();

    // Fallback documentado: si el backend usa path params, el query también suele aceptarse.
    final url =
        '$base/GetPdf?CodigoEmpresa=$codigoEmpresa&TipoDocumento=$tipoDocumento&Numero=$numero';
    debugPrint('[DocumentoPdfPage] URL construida desde DocumentoDto: $url');
    return url;
  }

  Future<void> _loadPdf() async {
    final url = _resolvePdfUrl();
    debugPrint('[DocumentoPdfPage] _loadPdf url: $url');

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(url);
      debugPrint('[DocumentoPdfPage] http.get $uri');
      final response = await http.get(uri);

      if (!mounted) return;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Error HTTP ${response.statusCode} al descargar PDF: ${response.body}');
      }

      final contentType = response.headers['content-type'] ?? '';
      debugPrint('[DocumentoPdfPage] content-type: $contentType, bytes: ${response.bodyBytes.length}');

      if (response.bodyBytes.isEmpty) {
        throw Exception('PDF vacío recibido desde $url');
      }

      // Guardar en temp vía path_provider
      final tempDir = await getTemporaryDirectory();
      if (!mounted) return;

      final fileName = widget.documento != null
          ? 'doc_${widget.documento!.codigoEmpresa ?? 'emp'}_${widget.documento!.tipoDocumento ?? 'doc'}_${widget.documento!.numero}.pdf'
          : 'documento_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      debugPrint('[DocumentoPdfPage] PDF guardado en: ${file.path}');

      if (!mounted) return;

      // Crear controlador pdfx con pinch-zoom
      final document = PdfDocument.openFile(file.path);
      final controller = PdfControllerPinch(
        document: document,
      );

      if (!mounted) return;
      setState(() {
        _pdfFile = file;
        _pdfController = controller;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('[DocumentoPdfPage] Error _loadPdf: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sharePdf() async {
    try {
      if (_pdfFile == null) {
        throw Exception('No hay PDF descargado para compartir');
      }
      debugPrint('[DocumentoPdfPage] Compartiendo PDF: ${_pdfFile!.path}');

      // Usar ShareService centralizado + fallback directo share_plus
      // Mantiene compatibilidad con lo solicitado: toolbar con share (share_plus)
      try {
        await _shareService.shareFile(_pdfFile!, _shareText());
      } catch (_) {
        // Fallback directo a share_plus por si ShareService lanza
        await Share.shareXFiles(
          [XFile(_pdfFile!.path)],
          text: _shareText(),
        );
      }
    } catch (e) {
      debugPrint('[DocumentoPdfPage] Error share: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e')),
      );
    }
  }

  String _shareText() {
    if (widget.documento != null) {
      final d = widget.documento!;
      return 'Documento ${d.tipoDocumento ?? 'PDF'} Nº ${d.numero}';
    }
    return 'Documento PDF';
  }

  void _onFirmar() {
    if (widget.documento != null) {
      debugPrint('[DocumentoPdfPage] Navegando a FirmaDocumentoPage');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FirmaDocumentoPage(documento: widget.documento!),
        ),
      );
    } else {
      // Solo pdfUrl sin DocumentoDto: informar o volver con result
      debugPrint('[DocumentoPdfPage] Firmar sin DocumentoDto - pdfUrl solo');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento no disponible para firmar (falta DocumentoDto)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ??
        (widget.documento != null
            ? '${widget.documento!.tipoDocumento ?? 'Documento'} Nº ${widget.documento!.numero}'
            : 'Vista PDF');

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir',
            onPressed: (_pdfFile == null || _isLoading) ? null : _sharePdf,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _onFirmar,
                icon: const Icon(Icons.draw, size: 18),
                label: const Text('Firmar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Descargando PDF...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Error al cargar PDF:\n$_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPdf,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfController == null) {
      return const Center(child: Text('No se pudo inicializar el visor PDF'));
    }

    // PdfView con pinch-zoom (pdfx PdfViewPinch)
    return PdfViewPinch(
      controller: _pdfController!,
      backgroundDecoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
      padding: 10,
      scrollDirection: Axis.vertical,
      onDocumentError: (error) {
        debugPrint('[DocumentoPdfPage] onDocumentError: $error');
        if (!mounted) return;
        setState(() {
          _error = error.toString();
        });
      },
      onDocumentLoaded: (doc) {
        debugPrint('[DocumentoPdfPage] Documento cargado: ${doc.pagesCount} páginas');
      },
    );
  }
}
