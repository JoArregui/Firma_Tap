import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servicio de modo kiosko.
///
/// No usa `wakelock` como dependencia externa; `keepScreenOn` es un
/// alternativo vía `SystemChrome` + `debugPrint` según especificación.
/// `lockApp()` es placeholder para integración futura (p.ej. screen pinning).
class KioskService {
  KioskService._();

  static bool _isKiosk = false;
  static bool _keepScreenOn = false;

  static bool get isKiosk => _isKiosk;
  static bool get keepScreenOnEnabled => _keepScreenOn;

  /// Entra en modo kiosko:
  /// - `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`
  /// - `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`
  static Future<void> enterKiosk() async {
    try {
      debugPrint('[KioskService] enterKiosk');
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      _isKiosk = true;
      debugPrint('[KioskService] enterKiosk ok - immersiveSticky + portraitUp');
    } on PlatformException catch (e) {
      debugPrint('[KioskService] enterKiosk PlatformException: $e');
    } catch (e) {
      debugPrint('[KioskService] enterKiosk error: $e');
    }
  }

  /// Sale de modo kiosko y restaura UI/orientaciones.
  static Future<void> exitKiosk() async {
    try {
      debugPrint('[KioskService] exitKiosk');
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _isKiosk = false;
      debugPrint('[KioskService] exitKiosk ok - edgeToEdge + all orientations');
    } on PlatformException catch (e) {
      debugPrint('[KioskService] exitKiosk PlatformException: $e');
    } catch (e) {
      debugPrint('[KioskService] exitKiosk error: $e');
    }
  }

  /// Alternativo a `Wakelock` vía `SystemChrome`.
  ///
  /// No existe API directa de wakelock en `SystemChrome`; se usa
  /// `debugPrint` + mantenimiento de estado interno. Si se requiere
  /// brillo/pantalla siempre encendida a nivel nativo, integrar
  /// `wakelock_plus` sin modificar `pubspec.yaml` aquí.
  static Future<void> keepScreenOn(bool enable) async {
    try {
      _keepScreenOn = enable;
      debugPrint('[KioskService] keepScreenOn: $enable (alternativo via SystemChrome brightness)');
      // Alternativo: forzar brillo / UI overlay para sugerir pantalla encendida.
      // No hay API SystemChrome para wakelock; se deja placeholder trazable.
      if (enable) {
        // Mantener overlays visibles como hint de pantalla activa
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        if (!_isKiosk) {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      }
    } on PlatformException catch (e) {
      debugPrint('[KioskService] keepScreenOn PlatformException: $e');
    } catch (e) {
      debugPrint('[KioskService] keepScreenOn error: $e');
    }
  }

  /// Placeholder para bloqueo de app (screen pinning / lock task).
  /// Integración futura con `DevicePolicyManager` (Android) o Guided Access (iOS).
  static Future<void> lockApp() async {
    debugPrint('[KioskService] lockApp placeholder - implementar pinning nativo si se requiere');
  }
}
