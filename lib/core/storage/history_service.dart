import 'dart:typed_data';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ---------------------------------------------------------------------------
// Modelo HistorialEntry
// ---------------------------------------------------------------------------
class HistorialEntry {
  final String id;
  final int numero;
  final String tipoDocumento;
  final String empresa;
  final String usuario;
  final DateTime fecha;
  final String hash;
  final double? lat;
  final double? lng;

  HistorialEntry({
    String? id,
    required this.numero,
    required this.tipoDocumento,
    required this.empresa,
    required this.usuario,
    DateTime? fecha,
    String? hash,
    this.lat,
    this.lng,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        fecha = fecha ?? DateTime.now(),
        hash = hash ?? '';

  /// Crea una entrada calculando el hash sha256 a partir de jpgBytes
  factory HistorialEntry.fromBytes({
    String? id,
    required int numero,
    required String tipoDocumento,
    required String empresa,
    required String usuario,
    required Uint8List jpgBytes,
    DateTime? fecha,
    double? lat,
    double? lng,
  }) {
    final h = HistoryService.computeHash(jpgBytes);
    return HistorialEntry(
      id: id,
      numero: numero,
      tipoDocumento: tipoDocumento,
      empresa: empresa,
      usuario: usuario,
      fecha: fecha,
      hash: h,
      lat: lat,
      lng: lng,
    );
  }

  /// Calcula hash desde base64 string
  factory HistorialEntry.fromBase64({
    String? id,
    required int numero,
    required String tipoDocumento,
    required String empresa,
    required String usuario,
    required String jpgBase64,
    DateTime? fecha,
    double? lat,
    double? lng,
  }) {
    String h = '';
    try {
      if (jpgBase64.isNotEmpty) {
        final bytes = base64Decode(jpgBase64);
        h = HistoryService.computeHash(bytes);
      }
    } catch (e) {
      debugPrint('[HistorialEntry] Error hash fromBase64: $e');
    }
    return HistorialEntry(
      id: id,
      numero: numero,
      tipoDocumento: tipoDocumento,
      empresa: empresa,
      usuario: usuario,
      fecha: fecha,
      hash: h,
      lat: lat,
      lng: lng,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'tipoDocumento': tipoDocumento,
      'empresa': empresa,
      'usuario': usuario,
      'fecha': fecha.toIso8601String(),
      'hash': hash,
      'lat': lat,
      'lng': lng,
    };
  }

  factory HistorialEntry.fromMap(Map<String, dynamic> map) {
    return HistorialEntry(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      numero: map['numero'] as int? ?? 0,
      tipoDocumento: map['tipoDocumento'] as String? ?? '',
      empresa: map['empresa'] as String? ?? '',
      usuario: map['usuario'] as String? ?? '',
      fecha: map['fecha'] != null
          ? DateTime.tryParse(map['fecha'] as String) ?? DateTime.now()
          : DateTime.now(),
      hash: map['hash'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
    );
  }

  HistorialEntry copyWith({
    String? id,
    int? numero,
    String? tipoDocumento,
    String? empresa,
    String? usuario,
    DateTime? fecha,
    String? hash,
    double? lat,
    double? lng,
  }) {
    return HistorialEntry(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      empresa: empresa ?? this.empresa,
      usuario: usuario ?? this.usuario,
      fecha: fecha ?? this.fecha,
      hash: hash ?? this.hash,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}

/// Adapter manual sin build_runner (usa Map). typeId 11 para no colisionar con FirmaPendiente (10)
class HistorialEntryAdapter extends TypeAdapter<HistorialEntry> {
  @override
  final int typeId = 11;

  @override
  HistorialEntry read(BinaryReader reader) {
    try {
      final map = (reader.read() as Map).cast<String, dynamic>();
      return HistorialEntry.fromMap(map);
    } catch (e) {
      debugPrint('[HistorialEntryAdapter] Error read: $e');
      rethrow;
    }
  }

  @override
  void write(BinaryWriter writer, HistorialEntry obj) {
    try {
      writer.write(obj.toMap());
    } catch (e) {
      debugPrint('[HistorialEntryAdapter] Error write: $e');
      rethrow;
    }
  }
}

// ---------------------------------------------------------------------------
// Servicio Historial auditoría local
// ---------------------------------------------------------------------------
class HistoryService {
  static const String _boxName = 'historial';

  static Box? _box;
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  /// Inicializa Hive (Hive.initFlutter) y abre box 'historial'
  static Future<void> init() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(HistorialEntryAdapter());
      }
      _box = await Hive.openBox(_boxName);
      _initialized = true;
      debugPrint('[HistoryService] Inicializado. Registros: ${_box?.length}');
    } catch (e, st) {
      debugPrint('[HistoryService] Error init: $e\n$st');
    }
  }

  static Future<Box> _ensureBox() async {
    try {
      if (_box != null && _box!.isOpen) return _box!;
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(HistorialEntryAdapter());
      }
      _box = await Hive.openBox(_boxName);
      return _box!;
    } catch (e, st) {
      debugPrint('[HistoryService] Error _ensureBox: $e\n$st');
      rethrow;
    }
  }

  /// Calcula hash SHA256 hex de jpgBytes
  static String computeHash(Uint8List jpgBytes) {
    try {
      return sha256.convert(jpgBytes).toString();
    } catch (e) {
      debugPrint('[HistoryService] Error computeHash: $e');
      return '';
    }
  }

  /// Añade una entrada al historial.
  /// Si el hash viene vacío y se proporciona jpgBytes se calcula automáticamente.
  static Future<void> add(HistorialEntry entry, {Uint8List? jpgBytes}) async {
    try {
      final box = await _ensureBox();
      HistorialEntry toStore = entry;
      if ((entry.hash.isEmpty) && jpgBytes != null && jpgBytes.isNotEmpty) {
        final h = computeHash(jpgBytes);
        toStore = entry.copyWith(hash: h);
      }
      await box.add(toStore.toMap());
      debugPrint('[HistoryService] add OK: ${toStore.numero} hash=${toStore.hash}');
    } catch (e, st) {
      debugPrint('[HistoryService] Error add: $e\n$st');
    }
  }

  /// Helper: añade entrada calculando hash directamente desde jpgBytes
  static Future<void> addWithBytes({
    required int numero,
    required String tipoDocumento,
    required String empresa,
    required String usuario,
    required Uint8List jpgBytes,
    double? lat,
    double? lng,
    DateTime? fecha,
    String? id,
  }) async {
    try {
      final entry = HistorialEntry.fromBytes(
        id: id,
        numero: numero,
        tipoDocumento: tipoDocumento,
        empresa: empresa,
        usuario: usuario,
        jpgBytes: jpgBytes,
        fecha: fecha,
        lat: lat,
        lng: lng,
      );
      await add(entry);
    } catch (e, st) {
      debugPrint('[HistoryService] Error addWithBytes: $e\n$st');
    }
  }

  /// Devuelve todos los registros ordenados por fecha descendente
  static Future<List<HistorialEntry>> getAll() async {
    try {
      final box = await _ensureBox();
      final List<HistorialEntry> list = [];
      for (var i = 0; i < box.length; i++) {
        try {
          final raw = box.getAt(i);
          if (raw == null) continue;
          final map = (raw as Map).cast<String, dynamic>();
          list.add(HistorialEntry.fromMap(map));
        } catch (e) {
          debugPrint('[HistoryService] Error parse índice $i: $e');
        }
      }
      // Orden descendente por fecha (más reciente primero)
      list.sort((a, b) => b.fecha.compareTo(a.fecha));
      return list;
    } catch (e, st) {
      debugPrint('[HistoryService] Error getAll: $e\n$st');
      return [];
    }
  }

  /// Limpia todo el historial
  static Future<void> clear() async {
    try {
      final box = await _ensureBox();
      await box.clear();
      debugPrint('[HistoryService] clear OK');
    } catch (e, st) {
      debugPrint('[HistoryService] Error clear: $e\n$st');
    }
  }

  /// Elimina una entrada por id
  static Future<void> removeById(String id) async {
    try {
      final box = await _ensureBox();
      for (var i = box.length - 1; i >= 0; i--) {
        final raw = box.getAt(i);
        if (raw == null) continue;
        final map = (raw as Map).cast<String, dynamic>();
        if (map['id'] == id) {
          await box.deleteAt(i);
          debugPrint('[HistoryService] removeById OK: $id');
          return;
        }
      }
    } catch (e, st) {
      debugPrint('[HistoryService] Error removeById: $e\n$st');
    }
  }
}
