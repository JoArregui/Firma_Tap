import 'package:shared_preferences/shared_preferences.dart';

/// Servicio centralizado para persistencia de sesión.
/// iOS/Android compatible (SharedPreferences). En iOS usa NSUserDefaults (cifrado a nivel OS).
/// Futuro: migrar a flutter_secure_storage si se requiere cifrado explícito.
class AuthStorage {
  static const _kUsuarioId = 'usuarioId';
  static const _kEmpresa = 'empresa';

  static Future<int?> getUsuarioId() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kUsuarioId);
  }

  static Future<String?> getEmpresa() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kEmpresa);
  }

  static Future<void> saveSession({required int usuarioId, required String empresa}) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kUsuarioId, usuarioId);
    await p.setString(_kEmpresa, empresa);
  }

  static Future<void> saveUsuarioId(int id) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kUsuarioId, id);
  }

  static Future<void> saveEmpresa(String codigo) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kEmpresa, codigo);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }

  static Future<bool> hasSession() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kUsuarioId) != null && p.getString(_kEmpresa) != null && p.getString(_kEmpresa)!.isNotEmpty;
  }
}
