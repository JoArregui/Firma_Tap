import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Servicio OCR basado en `google_mlkit_text_recognition: ^0.14.0`.
///
/// - [recognizeText] reconoce todo el texto de una imagen.
/// - [recognizeNumeroAlbaran] extrae el primer número de 4+ dígitos vía RegExp `r'\b\d{4,}\b'`.
/// - [close] libera recursos del [TextRecognizer].
///
/// Usa `debugPrint` y `try/catch` en todos los métodos públicos.
class OcrService {
  final TextRecognizer _recognizer;
  bool _closed = false;

  OcrService({TextRecognizer? recognizer})
      : _recognizer =
            recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  /// Reconoce todo el texto visible en la imagen de [imagePath].
  ///
  /// Retorna `''` si el path está vacío o si ocurre un error.
  Future<String> recognizeText(String imagePath) async {
    if (imagePath.isEmpty) {
      debugPrint('[OcrService] recognizeText: imagePath vacío');
      return '';
    }
    if (_closed) {
      debugPrint('[OcrService] recognizeText: recognizer ya cerrado');
      return '';
    }
    try {
      debugPrint('[OcrService] recognizeText path: $imagePath');
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await _recognizer.processImage(inputImage);
      final String text = recognizedText.text;
      debugPrint('[OcrService] recognizeText result length: ${text.length}');
      return text;
    } catch (e) {
      debugPrint('[OcrService] recognizeText error: $e');
      return '';
    }
  }

  /// Extrae el número de albarán de la imagen usando RegExp `r'\b\d{4,}\b'`.
  ///
  /// Internamente llama a [recognizeText] y retorna el primer match de 4+ dígitos.
  /// Retorna `''` si no se encuentra ningún número o si hay error.
  Future<String> recognizeNumeroAlbaran(String imagePath) async {
    try {
      debugPrint('[OcrService] recognizeNumeroAlbaran path: $imagePath');
      final String fullText = await recognizeText(imagePath);
      if (fullText.isEmpty) {
        debugPrint('[OcrService] recognizeNumeroAlbaran: texto vacío');
        return '';
      }
      final RegExp regExp = RegExp(r'\b\d{4,}\b');
      final RegExpMatch? match = regExp.firstMatch(fullText);
      final String result = match?.group(0) ?? '';
      debugPrint('[OcrService] recognizeNumeroAlbaran result: "$result"');
      return result;
    } catch (e) {
      debugPrint('[OcrService] recognizeNumeroAlbaran error: $e');
      return '';
    }
  }

  /// Libera recursos del [TextRecognizer]. Idempotente.
  Future<void> close() async {
    if (_closed) {
      debugPrint('[OcrService] close: ya cerrado');
      return;
    }
    try {
      debugPrint('[OcrService] close()');
      await _recognizer.close();
      _closed = true;
      debugPrint('[OcrService] close ok');
    } catch (e) {
      debugPrint('[OcrService] close error: $e');
    }
  }
}
