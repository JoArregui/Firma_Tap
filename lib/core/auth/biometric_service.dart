import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio de biometría + almacenamiento seguro.
///
/// Usa `local_auth` para biometría y `flutter_secure_storage` para
/// persistir `usuarioId` / `empresa` de forma cifrada.
///
/// Notas sobre `mounted`:
/// - Este servicio no tiene `BuildContext`; el llamante debe comprobar
///   `if (!mounted) return;` después de `await authenticate()` antes de
///   usar `context` / `Navigator`.
/// - Internamente se capturan `PlatformException` para no propagar crashes
///   en dispositivos sin biometría o con hardware no disponible.
class BiometricService {
  BiometricService({
    LocalAuthentication? auth,
    FlutterSecureStorage? storage,
  })  : _auth = auth ?? LocalAuthentication(),
        _storage = storage ?? const FlutterSecureStorage();

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  static const _kUsuarioId = 'usuarioId';
  static const _kEmpresa = 'empresa';

  /// Indica si el dispositivo puede comprobar biometría.
  /// Maneja `PlatformException` y retorna `false` en caso de error.
  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] canCheckBiometrics PlatformException: $e');
      return false;
    } catch (e) {
      debugPrint('[BiometricService] canCheckBiometrics error: $e');
      return false;
    }
  }

  /// Comprueba disponibilidad real: `canCheckBiometrics` + `isDeviceSupported`.
  /// Maneja `PlatformException`.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] isBiometricAvailable PlatformException: $e');
      return false;
    } catch (e) {
      debugPrint('[BiometricService] isBiometricAvailable error: $e');
      return false;
    }
  }

  /// Lista de biométricos enrolados (huella, facial, etc.). Vacía = no enrolado.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final list = await _auth.getAvailableBiometrics();
      debugPrint('[BiometricService] getAvailableBiometrics: $list');
      return list;
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] getAvailableBiometrics PlatformException: $e');
      return [];
    }
  }

  /// Etiqueta humana según lo enrolado: huella, Face ID, o genérico biometría.
  /// "huella" es un tipo de biometría, no una opción separada.
  Future<String> getBiometryLabel() async {
    final list = await getAvailableBiometrics();
    final hasFingerprint = list.any((t) => t == BiometricType.fingerprint || t == BiometricType.strong || t == BiometricType.weak);
    final hasFace = list.any((t) => t == BiometricType.face);
    if (hasFingerprint && hasFace) return 'huella / Face ID';
    if (hasFingerprint) return 'huella';
    if (hasFace) return 'Face ID';
    if (list.isNotEmpty) return 'biometría';
    // Fallback si no se pudo enumerar pero isBiometricAvailable==true
    return 'huella / Face ID';
  }

  /// Autentica al usuario.
  ///
  /// Usa `localizedReason: 'Autentícate para acceder'` y `biometricOnly: false`
  /// para permitir fallback a PIN/patrón del sistema.
  /// Maneja `PlatformException`. El llamante debe verificar `mounted` tras el `await`.
  Future<bool> authenticate() async {
    final r = await authenticateDetailed();
    return r.$1;
  }

  /// Variante con detalle de error: (ok, code, message)
  Future<(bool, String?, String?)> authenticateDetailed() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Autentícate para acceder',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      debugPrint('[BiometricService] authenticateDetailed ok=$ok');
      return (ok, null, null);
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] authenticateDetailed PlatformException: code=${e.code} msg=${e.message} details=${e.details}');
      return (false, e.code, e.message);
    } catch (e) {
      debugPrint('[BiometricService] authenticateDetailed error: $e');
      return (false, 'Unknown', e.toString());
    }
  }

  /// Guarda credenciales seguras en `FlutterSecureStorage`.
  /// Keys: `usuarioId` / `empresa`.
  Future<void> saveCredentials(String usuarioId, String empresa) async {
    try {
      await _storage.write(key: _kUsuarioId, value: usuarioId);
      await _storage.write(key: _kEmpresa, value: empresa);
      debugPrint('[BiometricService] saveCredentials ok');
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] saveCredentials PlatformException: $e');
      rethrow;
    }
  }

  /// Obtiene credenciales guardadas. Retorna mapa con `usuarioId` y `empresa` (nullable).
  Future<Map<String, String?>> getCredentials() async {
    try {
      final usuarioId = await _storage.read(key: _kUsuarioId);
      final empresa = await _storage.read(key: _kEmpresa);
      return {
        _kUsuarioId: usuarioId,
        _kEmpresa: empresa,
      };
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] getCredentials PlatformException: $e');
      return {_kUsuarioId: null, _kEmpresa: null};
    }
  }

  /// Limpia credenciales seguras.
  Future<void> clear() async {
    try {
      await _storage.delete(key: _kUsuarioId);
      await _storage.delete(key: _kEmpresa);
      debugPrint('[BiometricService] clear ok');
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] clear PlatformException: $e');
    }
  }

  /// Indica si existe sesión segura (ambas keys presentes y no vacías).
  Future<bool> hasSecureSession() async {
    try {
      final creds = await getCredentials();
      final u = creds[_kUsuarioId];
      final e = creds[_kEmpresa];
      return u != null && u.isNotEmpty && e != null && e.isNotEmpty;
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] hasSecureSession PlatformException: $e');
      return false;
    }
  }
}
