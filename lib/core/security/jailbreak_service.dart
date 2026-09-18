import 'package:flutter/foundation.dart';
import 'package:freerasp/freerasp.dart';

/// Servicio de detección jailbreak/root y amenazas vía freeRASP (Talsec).
///
/// Usa `freerasp: ^6.12.0` con [TalsecConfig] (`isProd: false`, `watcherMail`,
/// configuraciones Android/iOS). Expone [init] y [isDeviceSecure].
///
/// Config enterprise: `assets/certs` + `pirineosapi` ya definidos en
/// [PinningClient]; este servicio complementa con hardening de dispositivo.
class JailbreakService {
  bool _initialized = false;
  bool _isSecure = true;
  bool _isObfuscationMissing = false;
  final List<Threat> _detectedThreats = [];

  List<Threat> get detectedThreats => List.unmodifiable(_detectedThreats);
  bool get isObfuscationMissing => _isObfuscationMissing;
  bool get isInitialized => _initialized;

  /// Inicializa freeRASP. Debe llamarse en `main()` antes de `runApp`.
  ///
  /// Configura [TalsecConfig] con:
  /// - `isProd: false` (dev/staging, cambiar a true en release)
  /// - `watcherMail: security@ecomputer.es`
  /// - `androidConfig` / `iosConfig` mínimos para 6.12.0
  /// - Listener para `isMissingObfuscation` vía `Threat.obfuscationIssues`
  Future<void> init() async {
    if (_initialized) {
      debugPrint('[JailbreakService] ya inicializado');
      return;
    }
    try {
      final config = TalsecConfig(
        watcherMail: 'security@ecomputer.es',
        isProd: false,
        androidConfig: AndroidConfig(
          packageName: 'com.ecomputer.firmatap',
          signingCertHashes: ['AKoRuyLMM91E7l66BDK5LVSAq9KnsHbsQ9hW3ocS/DPo='],
          supportedStores: const ['com.android.vending'],
        ),
        iosConfig: IOSConfig(
          bundleIds: const ['com.ecomputer.firmatap'],
          teamId: 'TEAMID1234',
        ),
      );

      // Callback de amenazas — mapea directamente los flags que pide el spec:
      // isMissingObfuscation -> Threat.obfuscationIssues
      // privilegedAccess -> Threat.privilegedAccess (root/jailbreak)
      // debug, hooks, simulator, etc.
      final callback = ThreatCallback(
        onPrivilegedAccess: () {
          debugPrint('[JailbreakService] Threat: privilegedAccess (root/jailbreak)');
          _isSecure = false;
          _addThreat(Threat.privilegedAccess);
        },
        onDebug: () {
          debugPrint('[JailbreakService] Threat: debug');
          _addThreat(Threat.debug);
        },
        onSimulator: () {
          debugPrint('[JailbreakService] Threat: simulator');
          _addThreat(Threat.simulator);
        },
        onAppIntegrity: () {
          debugPrint('[JailbreakService] Threat: appIntegrity');
          _isSecure = false;
          _addThreat(Threat.appIntegrity);
        },
        onObfuscationIssues: () {
          debugPrint('[JailbreakService] Threat: obfuscationIssues (isMissingObfuscation)');
          _isObfuscationMissing = true;
          _addThreat(Threat.obfuscationIssues);
        },
        onHooks: () {
          debugPrint('[JailbreakService] Threat: hooks (Frida/Xposed)');
          _isSecure = false;
          _addThreat(Threat.hooks);
        },
        onDeviceBinding: () {
          debugPrint('[JailbreakService] Threat: deviceBinding');
          _addThreat(Threat.deviceBinding);
        },
        onUnofficialStore: () {
          debugPrint('[JailbreakService] Threat: unofficialStore');
          _addThreat(Threat.unofficialStore);
        },
        onSystemVPN: () {
          debugPrint('[JailbreakService] Threat: systemVPN');
          _addThreat(Threat.systemVPN);
        },
        onDevMode: () {
          debugPrint('[JailbreakService] Threat: devMode');
          _addThreat(Threat.devMode);
        },
        onADBEnabled: () {
          debugPrint('[JailbreakService] Threat: adbEnabled');
          _addThreat(Threat.adbEnabled);
        },
        onScreenshot: () {
          debugPrint('[JailbreakService] Threat: screenshot');
          _addThreat(Threat.screenshot);
        },
        onScreenRecording: () {
          debugPrint('[JailbreakService] Threat: screenRecording');
          _addThreat(Threat.screenRecording);
        },
        onSecureHardwareNotAvailable: () {
          debugPrint('[JailbreakService] Threat: secureHardwareNotAvailable');
          _addThreat(Threat.secureHardwareNotAvailable);
        },
        onPasscode: () {
          debugPrint('[JailbreakService] Threat: passcode not set');
          _addThreat(Threat.passcode);
        },
      );

      // Registrar listener antes de start para no perder eventos tempranos.
      Talsec.instance.attachListener(callback);

      await Talsec.instance.start(config);
      _initialized = true;
      debugPrint('[JailbreakService] freeRASP iniciado isProd:false watcherMail:security@ecomputer.es');
    } catch (e, st) {
      debugPrint('[JailbreakService] init error: $e\n$st');
      // En plataformas no soportadas (windows/linux) freerasp lanza UnimplementedError
      // — marcar como inicializado para no reintentar en bucle, pero seguro.
      _initialized = true;
      _isSecure = true;
    }
  }

  void _addThreat(Threat t) {
    try {
      if (!_detectedThreats.contains(t)) {
        _detectedThreats.add(t);
      }
      // Cualquier amenaza crítica marca dispositivo como no seguro
      if (t == Threat.privilegedAccess ||
          t == Threat.hooks ||
          t == Threat.appIntegrity ||
          t == Threat.privilegedAccess) {
        _isSecure = false;
      }
    } catch (e) {
      debugPrint('[JailbreakService] _addThreat error: $e');
    }
  }

  /// Retorna `true` si el dispositivo se considera seguro.
  ///
  /// Seguro = sin root/jailbreak, sin hooks, sin appIntegrity fallida.
  /// Si freeRASP aún no detectó amenazas, retorna `true`.
  Future<bool> isDeviceSecure() async {
    try {
      if (!_initialized) {
        debugPrint('[JailbreakService] isDeviceSecure llamado sin init(), retornando true provisional');
        return true;
      }
      debugPrint('[JailbreakService] isDeviceSecure: $_isSecure threats:$_detectedThreats obfuscationMissing:$_isObfuscationMissing');
      return _isSecure;
    } catch (e) {
      debugPrint('[JailbreakService] isDeviceSecure error: $e');
      return false;
    }
  }

  /// Limpia listener (útil en tests).
  void dispose() {
    try {
      Talsec.instance.detachListener();
      debugPrint('[JailbreakService] listener detached');
    } catch (e) {
      debugPrint('[JailbreakService] dispose error: $e');
    }
  }
}
