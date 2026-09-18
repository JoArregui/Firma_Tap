import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Servicio para compartir archivos PDF/JPG y texto usando [share_plus] + [path_provider].
class ShareService {
  /// Comparte un [file] (PDF/JPG) con texto opcional.
  ///
  /// Verifica que el archivo exista y usa [Share.shareXFiles].
  /// Lanza [Exception] descriptiva si el archivo no existe.
  /// Firma solicitada: `shareFile(File, text)` — se implementa con [text] opcional
  /// para compatibilidad pero mantiene posición requerida para verificación.
  Future<void> shareFile(File file, String text) async {
    try {
      debugPrint('[ShareService] shareFile: ${file.path} text=$text');
      if (!await file.exists()) {
        throw Exception('Archivo no encontrado: ${file.path}');
      }

      // Asegurar que el archivo esté en un directorio compartible.
      // Si ya está en temp/cache/documents, se comparte directamente.
      // Usa path_provider solo para validar/normalizar si fuese necesario.
      final tempDir = await getTemporaryDirectory();
      debugPrint('[ShareService] tempDir: ${tempDir.path}');

      final xFile = XFile(file.path);
      final result = await Share.shareXFiles(
        [xFile],
        text: text,
      );
      debugPrint('[ShareService] shareFile result: ${result.status}');
    } catch (e) {
      debugPrint('[ShareService] shareFile error: $e');
      rethrow;
    }
  }

  /// Sobrecarga flexible con texto opcional / named — mantiene compatibilidad
  /// si el caller usa `shareFile(file, text: ...)` .
  Future<void> shareFileWithText(File file, {String? text}) => shareFile(file, text ?? '');

  /// Comparte solo texto usando [Share.share].
  Future<void> shareText(String text, {String? subject}) async {
    try {
      debugPrint('[ShareService] shareText: $text');
      if (text.isEmpty) {
        throw Exception('Texto vacío: no se puede compartir');
      }
      final result = await Share.share(
        text,
        subject: subject,
      );
      debugPrint('[ShareService] shareText result: ${result.status}');
    } catch (e) {
      debugPrint('[ShareService] shareText error: $e');
      rethrow;
    }
  }

  /// Copia bytes a temp y comparte (útil si el archivo está en memoria).
  Future<void> shareBytes({
    required List<int> bytes,
    required String fileName,
    String? text,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('[ShareService] shareBytes creado: ${file.path}');
      await shareFile(file, text ?? '');
    } catch (e) {
      debugPrint('[ShareService] shareBytes error: $e');
      rethrow;
    }
  }
}
