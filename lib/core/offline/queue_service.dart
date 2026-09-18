import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType; 
import 'package:workmanager/workmanager.dart';

import '../../features/Services/firma_service.dart';

// ---------------------------------------------------------------------------
// Workmanager callback (top-level, requerido por Android)
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('[QueueService] Workmanager task ejecutado: $task');
      // Hive debe inicializarse dentro del isolate de Workmanager
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(FirmaPendienteAdapter());
      }
      // Reutiliza retryAll sin depender de init() previo del isolate principal
      await QueueService.retryAllIsolate();
    } catch (e, st) {
      debugPrint('[QueueService] Error en callbackDispatcher: $e\n$st');
    }
    return Future.value(true);
  });
}

// ---------------------------------------------------------------------------
// Modelo FirmaPendiente
// ---------------------------------------------------------------------------
class FirmaPendiente {
  final String codigoEmpresa;
  final String tipoDocumento;
  final int numero;
  final String usuario;
  /// jpgBytes codificado en base64 (para poder persistirlo en Hive como String)
  final String jpgBytes;
  final String? fotoPath;
  final double? lat;
  final double? lng;
  final DateTime timestamp;
  final int intentos;
  final String hash;

  FirmaPendiente({
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

  /// Calcula sha256 del contenido binario (base64 -> bytes -> sha256 hex)
  static String _computeHashFromBase64(String base64Str) {
    try {
      if (base64Str.isEmpty) return '';
      final bytes = base64Decode(base64Str);
      return sha256.convert(bytes).toString();
    } catch (e) {
      debugPrint('[FirmaPendiente] Error calculando hash: $e');
      return '';
    }
  }

  static String computeHash(Uint8List bytes) {
    try {
      return sha256.convert(bytes).toString();
    } catch (e) {
      debugPrint('[FirmaPendiente] Error computeHash: $e');
      return '';
    }
  }

  /// Factory helper para crear desde Uint8List directamente
  factory FirmaPendiente.fromBytes({
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
    return FirmaPendiente(
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

  Map<String, dynamic> toMap() {
    return {
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
  }

  factory FirmaPendiente.fromMap(Map<String, dynamic> map) {
    return FirmaPendiente(
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

  FirmaPendiente copyWith({
    String? codigoEmpresa,
    String? tipoDocumento,
    int? numero,
    String? usuario,
    String? jpgBytes,
    String? fotoPath,
    double? lat,
    double? lng,
    DateTime? timestamp,
    int? intentos,
    String? hash,
  }) {
    return FirmaPendiente(
      codigoEmpresa: codigoEmpresa ?? this.codigoEmpresa,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      numero: numero ?? this.numero,
      usuario: usuario ?? this.usuario,
      jpgBytes: jpgBytes ?? this.jpgBytes,
      fotoPath: fotoPath ?? this.fotoPath,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      timestamp: timestamp ?? this.timestamp,
      intentos: intentos ?? this.intentos,
      hash: hash ?? this.hash,
    );
  }
}

/// Adapter manual sin build_runner. Trabaja con Map para evitar
/// dependencia de código generado. Se registra con typeId 10.
class FirmaPendienteAdapter extends TypeAdapter<FirmaPendiente> {
  @override
  final int typeId = 10;

  @override
  FirmaPendiente read(BinaryReader reader) {
    try {
      final map = (reader.read() as Map).cast<String, dynamic>();
      return FirmaPendiente.fromMap(map);
    } catch (e) {
      debugPrint('[FirmaPendienteAdapter] Error read: $e');
      rethrow;
    }
  }

  @override
  void write(BinaryWriter writer, FirmaPendiente obj) {
    try {
      writer.write(obj.toMap());
    } catch (e) {
      debugPrint('[FirmaPendienteAdapter] Error write: $e');
      rethrow;
    }
  }
}

// ---------------------------------------------------------------------------
// Servicio de cola offline
// ---------------------------------------------------------------------------
class QueueService {
  static const String _boxName = 'cola_firmas';
  static const String _workTaskName = 'firmaTap_retry_periodic';
  static const String _workTaskTag = 'firma_retry';

  static Box? _box;
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  static bool _initialized = false;
  static bool _workmanagerInitialized = false;

  static bool get isInitialized => _initialized;

  /// Inicializa Hive, abre box, suscribe connectivity y registra Workmanager.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(FirmaPendienteAdapter());
      }
      _box = await Hive.openBox(_boxName);
      _listenConnectivity();
      await _registerPeriodicTask();
      _initialized = true;
      debugPrint('[QueueService] Inicializado. Pendientes: ${_box?.length}');
    } catch (e, st) {
      debugPrint('[QueueService] Error en init: $e\n$st');
    }
  }

  static Future<Box> _ensureBox() async {
    try {
      if (_box != null && _box!.isOpen) return _box!;
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(FirmaPendienteAdapter());
      }
      _box = await Hive.openBox(_boxName);
      return _box!;
    } catch (e, st) {
      debugPrint('[QueueService] Error _ensureBox: $e\n$st');
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // Connectivity: auto-retry cuando vuelve online
  // -------------------------------------------------------------------------
  static void _listenConnectivity() {
    try {
      _connectivitySub?.cancel();
      _connectivitySub = Connectivity().onConnectivityChanged.listen(
        (List<ConnectivityResult> results) async {
          try {
            final hasConnection = results.any((r) => r != ConnectivityResult.none);
            debugPrint('[QueueService] Connectivity changed: $results -> online=$hasConnection');
            if (hasConnection) {
              await retryAll();
            }
          } catch (e) {
            debugPrint('[QueueService] Error en listener connectivity: $e');
          }
        },
        onError: (e) => debugPrint('[QueueService] Connectivity stream error: $e'),
      );
    } catch (e) {
      debugPrint('[QueueService] Error _listenConnectivity: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Workmanager: tarea periódica cada 15 min
  // -------------------------------------------------------------------------
  static Future<void> _registerPeriodicTask() async {
    try {
      if (_workmanagerInitialized) return;
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      _workmanagerInitialized = true;
      debugPrint('[QueueService] Workmanager inicializado');

      await Workmanager().registerPeriodicTask(
        _workTaskName,
        _workTaskTag,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
      );
      debugPrint('[QueueService] Tarea periódica registrada cada 15min');
    } catch (e, st) {
      debugPrint('[QueueService] Error _registerPeriodicTask: $e\n$st');
    }
  }

  /// Permite cancelar la suscripción (ej. en tests / dispose)
  static Future<void> dispose() async {
    try {
      await _connectivitySub?.cancel();
      _connectivitySub = null;
    } catch (e) {
      debugPrint('[QueueService] Error dispose: $e');
    }
  }

  // -------------------------------------------------------------------------
  // CRUD
  // -------------------------------------------------------------------------

  /// Encola una firma pendiente. Calcula hash si viene vacío.
  static Future<void> enqueue(FirmaPendiente firma) async {
    try {
      final box = await _ensureBox();
      // Asegura hash coherente
      final firmaToStore = firma.hash.isEmpty && firma.jpgBytes.isNotEmpty
          ? firma.copyWith(hash: FirmaPendiente._computeHashFromBase64(firma.jpgBytes))
          : firma;
      await box.add(firmaToStore.toMap());
      debugPrint('[QueueService] Enqueue OK: ${firma.numero} (${firma.tipoDocumento}) total=${box.length}');
    } catch (e, st) {
      debugPrint('[QueueService] Error enqueue: $e\n$st');
    }
  }

  /// Devuelve todas las firmas pendientes
  static Future<List<FirmaPendiente>> getAll() async {
    try {
      final box = await _ensureBox();
      final List<FirmaPendiente> list = [];
      for (var i = 0; i < box.length; i++) {
        try {
          final raw = box.getAt(i);
          if (raw == null) continue;
          final map = (raw as Map).cast<String, dynamic>();
          list.add(FirmaPendiente.fromMap(map));
        } catch (e) {
          debugPrint('[QueueService] Error parseando item $i: $e');
        }
      }
      return list;
    } catch (e, st) {
      debugPrint('[QueueService] Error getAll: $e\n$st');
      return [];
    }
  }

  /// Elimina por índice (posición en Hive)
  static Future<void> removeAt(int index) async {
    try {
      final box = await _ensureBox();
      if (index < 0 || index >= box.length) {
        debugPrint('[QueueService] removeAt índice fuera de rango: $index');
        return;
      }
      await box.deleteAt(index);
      debugPrint('[QueueService] removeAt OK: $index');
    } catch (e, st) {
      debugPrint('[QueueService] Error removeAt: $e\n$st');
    }
  }

  /// Elimina por índice o por coincidencia (sobrecarga compat con spec: remove)
  static Future<void> remove(int index) async => removeAt(index);

  /// Elimina firma por número + tipoDocumento + empresa (útil para UI)
  static Future<void> removeByKeys({
    required int numero,
    String? tipoDocumento,
    String? codigoEmpresa,
  }) async {
    try {
      final box = await _ensureBox();
      for (var i = box.length - 1; i >= 0; i--) {
        final raw = box.getAt(i);
        if (raw == null) continue;
        final map = (raw as Map).cast<String, dynamic>();
        final f = FirmaPendiente.fromMap(map);
        final matchNumero = f.numero == numero;
        final matchTipo = tipoDocumento == null || f.tipoDocumento == tipoDocumento;
        final matchEmpresa = codigoEmpresa == null || f.codigoEmpresa == codigoEmpresa;
        if (matchNumero && matchTipo && matchEmpresa) {
          await box.deleteAt(i);
          debugPrint('[QueueService] removeByKeys OK: $numero');
          return;
        }
      }
    } catch (e, st) {
      debugPrint('[QueueService] Error removeByKeys: $e\n$st');
    }
  }

  // -------------------------------------------------------------------------
  // Retry
  // -------------------------------------------------------------------------

  /// Reintenta todas las firmas pendientes.
  /// - Decodifica jpgBytes base64 -> Uint8List
  /// - Si tiene fotoPath válido, envía multipart con foto
  /// - Si no, llama a FirmaService.enviarFirma
  static Future<void> retryAll() async {
    try {
      final box = await _ensureBox();
      if (box.isEmpty) {
        debugPrint('[QueueService] retryAll: cola vacía');
        return;
      }
      debugPrint('[QueueService] retryAll: ${box.length} pendientes');

      // Recorremos con índice manual porque borramos/insertamos durante iteración
      for (var i = 0; i < box.length; i++) {
        Map<String, dynamic>? map;
        FirmaPendiente? firma;
        try {
          final raw = box.getAt(i);
          if (raw == null) continue;
          map = (raw as Map).cast<String, dynamic>();
          firma = FirmaPendiente.fromMap(map);
        } catch (e) {
          debugPrint('[QueueService] retryAll parse error índice $i: $e');
          continue;
        }

        try {
          final Uint8List jpgBytes = base64Decode(firma.jpgBytes);

          final hasFoto = firma.fotoPath != null &&
              firma.fotoPath!.isNotEmpty &&
              await File(firma.fotoPath!).exists();

          if (hasFoto) {
            await _enviarFirmaConFoto(firma: firma, jpgBytes: jpgBytes);
          } else {
            await FirmaService.enviarFirma(
              jpgBytes: jpgBytes,
              codigoEmpresa: firma.codigoEmpresa,
              tipoDocumento: firma.tipoDocumento,
              numero: firma.numero,
              usuario: firma.usuario,
            );
          }

          // Éxito -> eliminar de la cola
          await box.deleteAt(i);
          i--; // ajustar índice tras borrar
          debugPrint('[QueueService] retryAll éxito: ${firma.numero}');
        } catch (e, st) {
          debugPrint('[QueueService] retryAll fallo ${firma.numero}: $e\n$st');
          // Incrementa intentos y actualiza registro
          try {
            final updated = firma.copyWith(intentos: firma.intentos + 1);
            await box.putAt(i, updated.toMap());
          } catch (e2) {
            debugPrint('[QueueService] Error actualizando intentos: $e2');
          }
        }
      }
    } catch (e, st) {
      debugPrint('[QueueService] Error retryAll: $e\n$st');
    }
  }

  /// Variante usada desde el isolate de Workmanager (reabre box independiente)
  static Future<void> retryAllIsolate() async {
    try {
      final box = await Hive.openBox(_boxName);
      if (box.isEmpty) {
        debugPrint('[QueueService][Isolate] cola vacía');
        return;
      }
      for (var i = 0; i < box.length; i++) {
        final raw = box.getAt(i);
        if (raw == null) continue;
        final map = (raw as Map).cast<String, dynamic>();
        final firma = FirmaPendiente.fromMap(map);
        try {
          final Uint8List jpgBytes = base64Decode(firma.jpgBytes);
          final hasFoto = firma.fotoPath != null &&
              firma.fotoPath!.isNotEmpty &&
              await File(firma.fotoPath!).exists();
          if (hasFoto) {
            await _enviarFirmaConFoto(firma: firma, jpgBytes: jpgBytes);
          } else {
            await FirmaService.enviarFirma(
              jpgBytes: jpgBytes,
              codigoEmpresa: firma.codigoEmpresa,
              tipoDocumento: firma.tipoDocumento,
              numero: firma.numero,
              usuario: firma.usuario,
            );
          }
          await box.deleteAt(i);
          i--;
          debugPrint('[QueueService][Isolate] éxito: ${firma.numero}');
        } catch (e) {
          debugPrint('[QueueService][Isolate] fallo ${firma.numero}: $e');
          final updated = firma.copyWith(intentos: firma.intentos + 1);
          await box.putAt(i, updated.toMap());
        }
      }
    } catch (e, st) {
      debugPrint('[QueueService] Error retryAllIsolate: $e\n$st');
    }
  }

  /// Envía firma + foto como multipart a mismo endpoint.
  /// Si el backend espera sólo 'firma', se envían dos ficheros: 'firma' y 'foto'.
  static Future<void> _enviarFirmaConFoto({
    required FirmaPendiente firma,
    required Uint8List jpgBytes,
  }) async {
    try {
      final url = Uri.parse('https://pirineosapi.ecomputer.es/DocumentoAFirmar/SubirFirma');
      final request = http.MultipartRequest('POST', url)
        ..fields['CodigoEmpresa'] = firma.codigoEmpresa
        ..fields['TipoDocumento'] = firma.tipoDocumento
        ..fields['Numero'] = firma.numero.toString()
        ..fields['Usuario'] = firma.usuario
        ..files.add(http.MultipartFile.fromBytes(
          'firma',
          jpgBytes,
          filename: '${firma.numero}.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));

      // Adjunta foto si existe
      final fotoFile = File(firma.fotoPath!);
      final fotoBytes = await fotoFile.readAsBytes();
      final ext = firma.fotoPath!.split('.').last.toLowerCase();
      final mimeSub = (ext == 'png') ? 'png' : 'jpeg';
      request.files.add(http.MultipartFile.fromBytes(
        'foto',
        fotoBytes,
        filename: 'foto_${firma.numero}.$ext',
        contentType: MediaType('image', mimeSub),
      ));

      request.headers['Accept'] = 'application/json';

      debugPrint('[QueueService] Enviando firma+foto: ${firma.numero} foto=${fotoBytes.length} bytes');

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw Exception('Error ${streamed.statusCode}: $body');
      }
      debugPrint('[QueueService] _enviarFirmaConFoto OK: ${firma.numero}');
    } catch (e, st) {
      debugPrint('[QueueService] Error _enviarFirmaConFoto: $e\n$st');
      rethrow;
    }
  }
}
