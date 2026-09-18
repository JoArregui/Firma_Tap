import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handler en background aislado. Debe ser top-level y anotado con
/// `@pragma('vm:entry-point')` para que no sea tree-shaken en release.
/// Se registra con `FirebaseMessaging.onBackgroundMessage`.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint(
        '[PushService][Background] messageId=${message.messageId} data=${message.data} notification=${message.notification?.title}');
  } catch (e, st) {
    debugPrint('[PushService][Background] Error: $e\n$st');
  }
}

/// Servicio singleton para FCM / APNs.
/// - Usa `firebase_core` + `firebase_messaging`.
/// - Guarda el token FCM en `FlutterSecureStorage`.
/// - Expone streams `onMessage` y `onMessageOpenedApp`.
class PushService {
  PushService._internal();
  static final PushService _instance = PushService._internal();
  factory PushService() => _instance;
  static PushService get instance => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'fcm_token';

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  /// Inicializa Firebase, registra el handler de background, escucha mensajes
  /// en foreground y guarda/actualiza el token.
  Future<void> init() async {
    if (_initialized) {
      debugPrint('[PushService] Ya inicializado, skip init()');
      return;
    }
    try {
      await Firebase.initializeApp();
      debugPrint('[PushService] Firebase.initializeApp OK');

      // Registro del handler background (requerido antes de cualquier otro uso)
      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);
      debugPrint('[PushService] onBackgroundMessage registrado');

      // Permisos (incluye provisional para iOS)
      await requestPermission();

      // Escucha foreground
      _onMessageSub?.cancel();
      _onMessageSub = FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) {
          debugPrint(
              '[PushService][onMessage] id=${message.messageId} title=${message.notification?.title} data=${message.data}');
        },
        onError: (e) => debugPrint('[PushService][onMessage] Error: $e'),
      );

      _onMessageOpenedSub?.cancel();
      _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          debugPrint(
              '[PushService][onMessageOpenedApp] id=${message.messageId} data=${message.data}');
        },
        onError: (e) =>
            debugPrint('[PushService][onMessageOpenedApp] Error: $e'),
      );

      // Token refresh listener
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen(
        (String token) async {
          try {
            await _storage.write(key: _tokenKey, value: token);
            debugPrint('[PushService] Token refrescado guardado: $token');
          } catch (e) {
            debugPrint('[PushService] Error guardando token refresh: $e');
          }
        },
        onError: (e) =>
            debugPrint('[PushService] onTokenRefresh Error: $e'),
      );

      // Obtiene y persiste el token inicial
      final token = await getToken();
      debugPrint('[PushService] init completado. Token inicial: $token');

      _initialized = true;
    } catch (e, st) {
      debugPrint('[PushService] Error en init(): $e\n$st');
    }
  }

  /// Solicita permisos de notificación.
  /// En iOS usa `provisional: true` para entrega silenciosa provisional
  /// (el usuario no ve prompt intrusivo de inmediato).
  Future<NotificationSettings> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
      debugPrint(
          '[PushService] requestPermission -> authorizationStatus=${settings.authorizationStatus} provisional=${settings.authorizationStatus == AuthorizationStatus.provisional} alert=${settings.alert} badge=${settings.badge} sound=${settings.sound}');
      return settings;
    } catch (e, st) {
      debugPrint('[PushService] Error requestPermission: $e\n$st');
      rethrow;
    }
  }

  /// Obtiene el token FCM/APNs actual y lo persiste en `FlutterSecureStorage`.
  /// Retorna null si no hay token o hay error.
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _storage.write(key: _tokenKey, value: token);
        debugPrint('[PushService] getToken OK: $token');
      } else {
        debugPrint('[PushService] getToken: token vacío o null');
      }
      return token;
    } catch (e, st) {
      debugPrint('[PushService] Error getToken: $e\n$st');
      return null;
    }
  }

  /// Lee el token persistido sin consultar a Firebase (útil offline).
  Future<String?> getStoredToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      debugPrint('[PushService] getStoredToken: ${token != null ? "encontrado" : "null"}');
      return token;
    } catch (e) {
      debugPrint('[PushService] Error getStoredToken: $e');
      return null;
    }
  }

  /// Borra el token persistido y hace delete del token en Firebase.
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      await _storage.delete(key: _tokenKey);
      debugPrint('[PushService] deleteToken OK');
    } catch (e, st) {
      debugPrint('[PushService] Error deleteToken: $e\n$st');
    }
  }

  /// Cancela suscripciones internas (útil en tests / dispose).
  Future<void> dispose() async {
    try {
      await _tokenRefreshSub?.cancel();
      await _onMessageSub?.cancel();
      await _onMessageOpenedSub?.cancel();
      _tokenRefreshSub = null;
      _onMessageSub = null;
      _onMessageOpenedSub = null;
      debugPrint('[PushService] dispose OK');
    } catch (e) {
      debugPrint('[PushService] Error dispose: $e');
    }
  }
}
