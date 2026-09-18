import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Servicio de voz basado en `speech_to_text: ^7.4.0`.
///
/// Maneja permisos de micrófono con `permission_handler`, inicialización,
/// escucha y detención. Usa `debugPrint` y `try/catch` en todos los métodos.
///
/// Ejemplo:
/// ```dart
/// final voice = VoiceService();
/// final ok = await voice.init();
/// if (ok) await voice.listen((text) => debugPrint(text));
/// ```
class VoiceService {
  final SpeechToText _speech;

  VoiceService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  /// Indica si actualmente está escuchando.
  bool get isListening {
    try {
      return _speech.isListening;
    } catch (e) {
      debugPrint('[VoiceService] isListening error: $e');
      return false;
    }
  }

  /// Inicializa el motor de reconocimiento de voz.
  ///
  /// - Solicita permiso de micrófono vía `permission_handler`.
  /// - Llama a `SpeechToText.initialize()`.
  /// Retorna `true` si la inicialización fue exitosa.
  Future<bool> init() async {
    try {
      debugPrint('[VoiceService] init()');

      // 1. Permiso de micrófono
      PermissionStatus status = await Permission.microphone.status;
      debugPrint('[VoiceService] Permission.microphone status: $status');

      if (status.isDenied || status.isRestricted) {
        debugPrint('[VoiceService] Solicitando permiso de micrófono...');
        status = await Permission.microphone.request();
        debugPrint('[VoiceService] Permission.microphone tras request: $status');
      }

      if (status.isPermanentlyDenied) {
        debugPrint('[VoiceService] Permiso de micrófono permanentemente denegado');
        return false;
      }

      if (!status.isGranted) {
        debugPrint('[VoiceService] Permiso de micrófono denegado: $status');
        return false;
      }

      // 2. Inicializar speech_to_text
      final bool available = await _speech.initialize(
        onError: (e) => debugPrint('[VoiceService] onError: $e'),
        onStatus: (s) => debugPrint('[VoiceService] onStatus: $s'),
      );
      debugPrint('[VoiceService] initialize result: $available');
      return available;
    } catch (e) {
      debugPrint('[VoiceService] init error: $e');
      return false;
    }
  }

  /// Inicia la escucha y entrega resultados vía [onResult].
  ///
  /// Requiere haber llamado [init] previamente. Si no está disponible
  /// intenta inicializar automáticamente.
  Future<void> listen(void Function(String text) onResult) async {
    try {
      debugPrint('[VoiceService] listen()');

      // Asegurar inicialización
      if (!_speech.isAvailable) {
        debugPrint('[VoiceService] listen: no disponible, intentando init()');
        final ok = await init();
        if (!ok) {
          debugPrint('[VoiceService] listen: init falló, no se puede escuchar');
          return;
        }
      }

      if (_speech.isListening) {
        debugPrint('[VoiceService] listen: ya está escuchando');
        return;
      }

      await _speech.listen(
        onResult: (result) {
          try {
            debugPrint('[VoiceService] onResult: ${result.recognizedWords}');
            onResult(result.recognizedWords);
          } catch (e) {
            debugPrint('[VoiceService] onResult callback error: $e');
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
        ),
      );
      debugPrint('[VoiceService] listen iniciado');
    } catch (e) {
      debugPrint('[VoiceService] listen error: $e');
    }
  }

  /// Detiene la escucha si está activa.
  Future<void> stop() async {
    try {
      debugPrint('[VoiceService] stop()');
      if (_speech.isListening) {
        await _speech.stop();
        debugPrint('[VoiceService] stop ok');
      } else {
        debugPrint('[VoiceService] stop: no estaba escuchando');
      }
    } catch (e) {
      debugPrint('[VoiceService] stop error: $e');
    }
  }
}
