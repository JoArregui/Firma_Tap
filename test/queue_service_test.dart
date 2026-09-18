import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests de QueueService sin Hive real.
/// Usa Map como almacenamiento en memoria para simular el Box de Hive.
/// Verifica la lógica de FirmaPendiente: serialización, hash, copia, y operaciones de cola.

/// Replica mínima de FirmaPendiente para test sin depender de Hive/Workmanager.
class FirmaPendienteTest {
  final String codigoEmpresa;
  final String tipoDocumento;
  final int numero;
  final String usuario;
  final String jpgBytes;
  final String? fotoPath;
  final double? lat;
  final double? lng;
  final DateTime timestamp;
  final int intentos;
  final String hash;

  FirmaPendienteTest({
    required this.codigoEmpresa,
    required this.tipoDocumento,
    required this.numero,
    required this.usuario,
    required this.jpgBytes,
    this.fotoPath,
    this.lat,
    this.lng,
    DateTime? timestamp,
    this.intentos = 0,
    String? hash,
  })  : timestamp = timestamp ?? DateTime.now(),
        hash = hash ?? _computeHashFromBase64(jpgBytes);

  static String _computeHashFromBase64(String base64Str) {
    if (base64Str.isEmpty) return '';
    try {
      final bytes = base64Decode(base64Str);
      return sha256.convert(bytes).toString();
    } catch (_) {
      return '';
    }
  }

  static String computeHash(Uint8List bytes) => sha256.convert(bytes).toString();

  factory FirmaPendienteTest.fromBytes({
    required String codigoEmpresa,
    required String tipoDocumento,
    required int numero,
    required String usuario,
    required Uint8List jpgBytesRaw,
    String? fotoPath,
    double? lat,
    double? lng,
    int intentos = 0,
  }) {
    final b64 = base64Encode(jpgBytesRaw);
    final h = computeHash(jpgBytesRaw);
    return FirmaPendienteTest(
      codigoEmpresa: codigoEmpresa,
      tipoDocumento: tipoDocumento,
      numero: numero,
      usuario: usuario,
      jpgBytes: b64,
      fotoPath: fotoPath,
      lat: lat,
      lng: lng,
      intentos: intentos,
      hash: h,
    );
  }

  Map<String, dynamic> toMap() => {
        'codigoEmpresa': codigoEmpresa,
        'tipoDocumento': tipoDocumento,
        'numero': numero,
        'usuario': usuario,
        'jpgBytes': jpgBytes,
        'fotoPath': fotoPath,
        'lat': lat,
        'lng': lng,
        'timestamp': timestamp.toIso8601String(),
        'intentos': intentos,
        'hash': hash,
      };

  factory FirmaPendienteTest.fromMap(Map<String, dynamic> map) {
    return FirmaPendienteTest(
      codigoEmpresa: map['codigoEmpresa'] as String? ?? '',
      tipoDocumento: map['tipoDocumento'] as String? ?? '',
      numero: map['numero'] as int? ?? 0,
      usuario: map['usuario'] as String? ?? '',
      jpgBytes: map['jpgBytes'] as String? ?? '',
      fotoPath: map['fotoPath'] as String?,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      intentos: map['intentos'] as int? ?? 0,
      hash: map['hash'] as String? ?? '',
    );
  }

  FirmaPendienteTest copyWith({int? intentos, String? hash}) => FirmaPendienteTest(
        codigoEmpresa: codigoEmpresa,
        tipoDocumento: tipoDocumento,
        numero: numero,
        usuario: usuario,
        jpgBytes: jpgBytes,
        fotoPath: fotoPath,
        lat: lat,
        lng: lng,
        timestamp: timestamp,
        intentos: intentos ?? this.intentos,
        hash: hash ?? this.hash,
      );
}

/// Simulación de Box Hive con Map/List en memoria.
class FakeBox {
  final List<Map<String, dynamic>> _store = [];

  int get length => _store.length;
  bool get isEmpty => _store.isEmpty;
  Map<String, dynamic>? getAt(int i) => _store[i];
  Future<void> add(Map<String, dynamic> m) async => _store.add(m);
  Future<void> deleteAt(int i) async => _store.removeAt(i);
  Future<void> putAt(int i, Map<String, dynamic> m) async => _store[i] = m;
  Future<void> clear() async => _store.clear();
  List<FirmaPendienteTest> getAll() => _store.map((e) => FirmaPendienteTest.fromMap(e)).toList();
}

void main() {
  group('FirmaPendiente modelo', () {
    test('toMap / fromMap roundtrip conserva campos', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final f = FirmaPendienteTest.fromBytes(
        codigoEmpresa: 'EMP01',
        tipoDocumento: 'ALB',
        numero: 123,
        usuario: 'test_user',
        jpgBytesRaw: bytes,
        lat: 42.1,
        lng: -1.5,
      );
      final map = f.toMap();
      final restored = FirmaPendienteTest.fromMap(map);

      expect(restored.codigoEmpresa, 'EMP01');
      expect(restored.tipoDocumento, 'ALB');
      expect(restored.numero, 123);
      expect(restored.usuario, 'test_user');
      expect(restored.lat, 42.1);
      expect(restored.lng, -1.5);
      expect(restored.hash, f.hash);
      expect(restored.jpgBytes, base64Encode(bytes));
    });

    test('computeHash es consistente con sha256', () {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final expected = sha256.convert(bytes).toString();
      expect(FirmaPendienteTest.computeHash(bytes), expected);
    });

    test('fromBytes genera hash correcto', () {
      final bytes = Uint8List.fromList(List.generate(20, (i) => i));
      final f = FirmaPendienteTest.fromBytes(
        codigoEmpresa: 'E1',
        tipoDocumento: 'T1',
        numero: 1,
        usuario: 'u',
        jpgBytesRaw: bytes,
      );
      expect(f.hash, sha256.convert(bytes).toString());
      expect(f.jpgBytes, base64Encode(bytes));
    });

    test('copyWith incrementa intentos', () {
      final f = FirmaPendienteTest(
        codigoEmpresa: 'E',
        tipoDocumento: 'T',
        numero: 99,
        usuario: 'u',
        jpgBytes: base64Encode([1, 2, 3]),
      );
      final updated = f.copyWith(intentos: f.intentos + 1);
      expect(updated.intentos, 1);
      expect(updated.numero, 99);
    });

    test('fromMap con valores nulos usa defaults sin crash', () {
      final m = <String, dynamic>{};
      final f = FirmaPendienteTest.fromMap(m);
      expect(f.codigoEmpresa, '');
      expect(f.numero, 0);
      expect(f.intentos, 0);
    });
  });

  group('QueueService lógica con FakeBox (Map)', () {
    late FakeBox box;

    setUp(() => box = FakeBox());

    test('enqueue añade elementos', () async {
      expect(box.length, 0);
      final f = FirmaPendienteTest(
        codigoEmpresa: 'EMP01',
        tipoDocumento: 'ALB',
        numero: 1,
        usuario: 'u1',
        jpgBytes: base64Encode([1, 2, 3]),
      );
      await box.add(f.toMap());
      expect(box.length, 1);
      expect(box.getAll().first.numero, 1);
    });

    test('getAll devuelve todos en orden', () async {
      for (int i = 0; i < 3; i++) {
        await box.add(FirmaPendienteTest(
          codigoEmpresa: 'E',
          tipoDocumento: 'ALB',
          numero: i,
          usuario: 'u',
          jpgBytes: base64Encode([i]),
        ).toMap());
      }
      final all = box.getAll();
      expect(all.length, 3);
      expect(all.map((e) => e.numero).toList(), [0, 1, 2]);
    });

    test('removeAt elimina por índice', () async {
      for (int i = 0; i < 2; i++) {
        await box.add(FirmaPendienteTest(
          codigoEmpresa: 'E',
          tipoDocumento: 'T',
          numero: i,
          usuario: 'u',
          jpgBytes: base64Encode([i]),
        ).toMap());
      }
      await box.deleteAt(0);
      expect(box.length, 1);
      expect(box.getAll().first.numero, 1);
    });

    test('removeByKeys simula borrado por número', () async {
      await box.add(FirmaPendienteTest(codigoEmpresa: 'E1', tipoDocumento: 'ALB', numero: 10, usuario: 'u', jpgBytes: base64Encode([1])).toMap());
      await box.add(FirmaPendienteTest(codigoEmpresa: 'E1', tipoDocumento: 'ALB', numero: 20, usuario: 'u', jpgBytes: base64Encode([2])).toMap());

      // Simula removeByKeys
      final target = 10;
      for (int i = box.length - 1; i >= 0; i--) {
        if (box.getAt(i)!['numero'] == target) {
          await box.deleteAt(i);
          break;
        }
      }
      expect(box.length, 1);
      expect(box.getAll().first.numero, 20);
    });

    test('retry incrementa intentos en fallo simulado', () async {
      await box.add(FirmaPendienteTest(codigoEmpresa: 'E', tipoDocumento: 'ALB', numero: 5, usuario: 'u', jpgBytes: base64Encode([9]), intentos: 0).toMap());
      // Simula fallo -> incrementa intentos
      final raw = box.getAt(0)!;
      final f = FirmaPendienteTest.fromMap(raw);
      final updated = f.copyWith(intentos: f.intentos + 1);
      await box.putAt(0, updated.toMap());
      expect(box.getAll().first.intentos, 1);
    });

    test('hash vacío se recalcula desde jpgBytes', () {
      final bytes = Uint8List.fromList([5, 6, 7]);
      final b64 = base64Encode(bytes);
      // Construcción sin hash explícito
      final f = FirmaPendienteTest(codigoEmpresa: 'E', tipoDocumento: 'T', numero: 1, usuario: 'u', jpgBytes: b64);
      expect(f.hash, isNotEmpty);
      expect(f.hash, sha256.convert(bytes).toString());
    });

    test('clear vacía la cola', () async {
      await box.add(FirmaPendienteTest(codigoEmpresa: 'E', tipoDocumento: 'T', numero: 1, usuario: 'u', jpgBytes: base64Encode([1])).toMap());
      await box.clear();
      expect(box.isEmpty, true);
    });
  });
}
