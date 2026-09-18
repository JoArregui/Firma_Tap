import 'dart:async';
import 'package:firma_tap/features/services/firma_service.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import 'package:firma_tap/features/models/documento_dto.dart';

class FirmasPage extends StatefulWidget {
  final DocumentoDto doc;

  const FirmasPage({super.key, required this.doc});

  @override
  State<FirmasPage> createState() => _FirmasPageState();
}

class _FirmasPageState extends State<FirmasPage> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  final GlobalKey _signatureKey = GlobalKey();
  bool _isSaving = false;

  Future<void> _guardarFirma() async {
    debugPrint('🖊️ Iniciando _guardarFirma');

    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, firma antes de continuar')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      //Mostrar dialogo de carga
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Enviando Firma...')),
            ],
          ),
        ),
      );

      final jpgByte = await FirmaService.convertirFirmaABytesJpg(
        controller: _controller,
      );

      await FirmaService.enviarFirma(
        jpgBytes: jpgByte,
        codigoEmpresa: widget.doc.codigoEmpresa ?? 'Desconocido',
        tipoDocumento: widget.doc.tipoDocumento ?? 'Desconocido',
        numero: widget.doc.numero,
        usuario: widget.doc.usuario.toString(),
      );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop(); //Cierra el dialogo

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firma enviada correctamente')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop(); //Cierra el dialogo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al guardar la firma: $e',
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;

    return Scaffold(
      appBar: AppBar(
        title: Text('Firma ${doc.tipoDocumento} Nº ${doc.numero}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                key: _signatureKey,
                color: Colors.grey[200],
                child: Signature(controller: _controller),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _controller.clear,
                    icon: const Icon(Icons.clear),
                    label: const Text('Borrar'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _guardarFirma,
                    icon: const Icon(Icons.check),
                    label: const Text('Guardar firma'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}