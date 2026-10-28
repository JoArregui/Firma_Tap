import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio centralizado para persistencia de sesión.
/// iOS/Android compatible (SharedPreferences). En iOS usa NSUserDefaults (cifrado a nivel OS).
/// Futuro: migrar a flutter_secure_storage si se requiere cifrado explícito.
/// Patrones: usa getInstance() cached para rendimiento, validates session state.
class AuthStorage {
  static const _kUsuarioId = 'usuarioId';
  static const _kEmpresa = 'empresa';
  static const _kBiometriaHabilitada = 'biometria_habilitada';
  static const _kBiometriaOfrecida = 'biometria_ofrecida';

  /// Obtiene el ID de usuario almacenado.
  /// Retorna null si no hay sesión activa.
  static Future<int?> getUsuarioId() async {
    final p = await SharedPreferences.getInstance();
    final value = p.getInt(_kUsuarioId);
    return value;
  }

  /// Obtiene el código de empresa almacenado.
  /// Retorna null si no hay sesión activa.
  static Future<String?> getEmpresa() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kEmpresa);
  }

  /// Guarda la sesión completa (usuario + empresa + flags de biometría).
  /// Usa SharedPreferences.getInstance() una sola vez para eficiencia.
  static Future<void> saveSession({
    required int usuarioId,
    required String empresa,
    required bool biometriaHabilitada,
    required bool biometriaOfrecida,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kUsuarioId, usuarioId);
    await p.setString(_kEmpresa, empresa);
    await p.setBool(_kBiometriaHabilitada, biometriaHabilitada);
    await p.setBool(_kBiometriaOfrecida, biometriaOfrecida);
    debugPrint('[AuthStorage] Session saved: usuarioId=$usuarioId, empresa=$empresa');
  }

  /// Guarda solo el ID de usuario (uso rápido/sesión temporal).
  static Future<void> saveUsuarioId(int id) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kUsuarioId, id);
  }

  /// Guarda el código de empresa.
  static Future<void> saveEmpresa(String codigo) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kEmpresa, codigo);
  }

  /// Guarda los flags de biometría (estado de disponibilidad).
  static Future<void> saveBiometryFlags({
    required bool habilitada,
    required bool ofrecida,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kBiometriaHabilitada, habilitada);
    await p.setBool(_kBiometriaOfrecida, ofrecida);
  }

  /// Limpia toda la sesión y flags de biometría.
  /// Reinicia el estado como si fuera nuevo usuario.
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    debugPrint('[AuthStorage] Session cleared');
  }

  /// Verifica si hay una sesión activa completa.
  /// Devuelve true solo si todas las keys necesarias están presentes y no vacías.
  static Future<bool> hasSession() async {
    final p = await SharedPreferences.getInstance();
    final usuarioId = p.getInt(_kUsuarioId);
    final empresa = p.getString(_kEmpresa);
    final biometriaHabilitada = p.getBool(_kBiometriaHabilitada) ?? false;
    final biometriaOfrecida = p.getBool(_kBiometriaOfrecida) ?? false;

    final tieneSesion = usuarioId != null && usuarioId > 0 && empresa != null && empresa.isNotEmpty;
    final biometriaConfigurada = biometriaHabilitada && biometriaOfrecida;

    return tieneSesion && biometriaConfigurada;
  }

  /// Verifica sesión mínima (solo usuario + empresa, sin biometría).
  static Future<bool> hasMinimalSession() async {
    final p = await SharedPreferences.getInstance();
    final usuarioId = p.getInt(_kUsuarioId);
    final empresa = p.getString(_kEmpresa);

    return usuarioId != null && usuarioId > 0 && empresa != null && empresa.isNotEmpty;
  }
}