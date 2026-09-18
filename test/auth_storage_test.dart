import 'package:flutter_test/flutter_test.dart';

/// Tests de AuthStorage sin SharedPreferences real.
/// Usa Map en memoria como mock de SharedPreferences para validar la lógica de sesión.

/// Replica de AuthStorage usando Map, idéntica a la implementación real
/// pero desacoplada de SharedPreferences para tests puros.
class FakeAuthStorage {
  final Map<String, Object> _prefs = {};

  static const kUsuarioId = 'usuarioId';
  static const kEmpresa = 'empresa';

  Future<int?> getUsuarioId() async => _prefs[kUsuarioId] as int?;
  Future<String?> getEmpresa() async => _prefs[kEmpresa] as String?;

  Future<void> saveSession({required int usuarioId, required String empresa}) async {
    _prefs[kUsuarioId] = usuarioId;
    _prefs[kEmpresa] = empresa;
  }

  Future<void> saveUsuarioId(int id) async => _prefs[kUsuarioId] = id;
  Future<void> saveEmpresa(String codigo) async => _prefs[kEmpresa] = codigo;

  Future<void> clear() async => _prefs.clear();

  Future<bool> hasSession() async {
    final id = _prefs[kUsuarioId] as int?;
    final emp = _prefs[kEmpresa] as String?;
    return id != null && emp != null && emp.isNotEmpty;
  }

  int get size => _prefs.length;
}

void main() {
  group('AuthStorage con Fake Map', () {
    late FakeAuthStorage storage;

    setUp(() => storage = FakeAuthStorage());

    test('hasSession false al inicio vacío', () async {
      expect(await storage.hasSession(), false);
      expect(await storage.getUsuarioId(), isNull);
      expect(await storage.getEmpresa(), isNull);
    });

    test('saveSession persiste usuarioId y empresa', () async {
      await storage.saveSession(usuarioId: 42, empresa: 'EMP01');
      expect(await storage.getUsuarioId(), 42);
      expect(await storage.getEmpresa(), 'EMP01');
      expect(await storage.hasSession(), true);
    });

    test('saveUsuarioId actualiza solo usuarioId', () async {
      await storage.saveSession(usuarioId: 1, empresa: 'E1');
      await storage.saveUsuarioId(99);
      expect(await storage.getUsuarioId(), 99);
      expect(await storage.getEmpresa(), 'E1');
    });

    test('saveEmpresa actualiza solo empresa', () async {
      await storage.saveSession(usuarioId: 10, empresa: 'OLD');
      await storage.saveEmpresa('NEW');
      expect(await storage.getUsuarioId(), 10);
      expect(await storage.getEmpresa(), 'NEW');
    });

    test('clear borra todo', () async {
      await storage.saveSession(usuarioId: 5, empresa: 'EMP');
      expect(await storage.hasSession(), true);
      await storage.clear();
      expect(await storage.hasSession(), false);
      expect(storage.size, 0);
    });

    test('hasSession false si empresa vacía', () async {
      await storage.saveSession(usuarioId: 1, empresa: '');
      expect(await storage.hasSession(), false);
    });

    test('hasSession false si falta usuarioId', () async {
      await storage.saveEmpresa('EMP01');
      expect(await storage.hasSession(), false);
    });

    test('sobrescribe sesión correctamente', () async {
      await storage.saveSession(usuarioId: 1, empresa: 'E1');
      await storage.saveSession(usuarioId: 2, empresa: 'E2');
      expect(await storage.getUsuarioId(), 2);
      expect(await storage.getEmpresa(), 'E2');
    });

    test('getUsuarioId retorna null tras clear', () async {
      await storage.saveSession(usuarioId: 123, empresa: 'E');
      await storage.clear();
      expect(await storage.getUsuarioId(), isNull);
    });

    test('persistencia con Map conserva tipos', () async {
      await storage.saveSession(usuarioId: 999, empresa: 'EMPRESA_X');
      final id = await storage.getUsuarioId();
      final emp = await storage.getEmpresa();
      expect(id, isA<int>());
      expect(emp, isA<String>());
      expect(id, 999);
      expect(emp, 'EMPRESA_X');
    });
  });
}
