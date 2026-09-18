import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Cliente HTTP con certificate pinning para `https://pirineosapi.ecomputer.es`.
///
/// Usa `dart:io HttpClient` con `badCertificateCallback` que verifica el
/// SHA256 del certificado DER contra el pin extraído de
/// `assets/certs/pirineos.pem` o fallback hardcoded.
///
/// Provee [getPinned] y [postPinned] que retornan `http.Response`.
class PinningClient {
  static const String pinnedHost = 'pirineosapi.ecomputer.es';
  static const String certAssetPath = 'assets/certs/pirineos.pem';

  /// Placeholder base64 SHA256 — reemplazar con pin real en producción.
  /// Generado vía: `openssl x509 -in pirineos.pem -outform der | openssl dgst -sha256 -binary | openssl enc -base64`
  static const String hardcodedPinPlaceholder =
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

  static const Duration _timeout = Duration(seconds: 15);

  List<String> _pins = const [hardcodedPinPlaceholder];
  bool _initialized = false;

  List<String> get pins => List.unmodifiable(_pins);

  /// Inicializa pins leyendo `assets/certs/pirineos.pem` si existe.
  /// Si el asset contiene "# placeholder" o falla la lectura, usa fallback.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final raw = await rootBundle.loadString(certAssetPath);
      final extracted = _extractPinsFromPem(raw);
      if (extracted.isNotEmpty) {
        _pins = extracted;
        debugPrint('[PinningClient] pins cargados desde $certAssetPath: $_pins');
      } else {
        debugPrint(
            '[PinningClient] $certAssetPath sin pins válidos, usando fallback hardcoded');
        _pins = const [hardcodedPinPlaceholder];
      }
    } catch (e) {
      debugPrint('[PinningClient] no se pudo leer $certAssetPath: $e — fallback');
      _pins = const [hardcodedPinPlaceholder];
    }
    _initialized = true;
  }

  /// Extrae pins SHA256 base64 desde contenido PEM.
  /// Soporta:
  /// - líneas con pin base64 directo (44 chars con =)
  /// - bloque PEM -----BEGIN CERTIFICATE----- -> calcula sha256(DER)
  List<String> _extractPinsFromPem(String raw) {
    try {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed.startsWith('# placeholder')) {
        return [];
      }
      // Si contiene bloque PEM, calcular SHA256 del DER
      if (trimmed.contains('-----BEGIN CERTIFICATE-----')) {
        final b64Blocks = _pemToDerB64Blocks(trimmed);
        if (b64Blocks.isEmpty) return [];
        final pins = <String>[];
        for (final b64 in b64Blocks) {
          try {
            final der = base64Decode(b64.replaceAll(RegExp(r'\s'), ''));
            final digest = sha256.convert(der);
            pins.add(base64Encode(digest.bytes));
          } catch (e) {
            debugPrint('[PinningClient] error decodificando PEM block: $e');
          }
        }
        return pins;
      }
      // Fallback: buscar líneas que parezcan pins base64 (43-44 chars)
      final lines = trimmed.split(RegExp(r'[\r\n]+'));
      final pins = lines
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .where((l) => RegExp(r'^[A-Za-z0-9+/]{43}=$').hasMatch(l))
          .toList();
      return pins;
    } catch (e) {
      debugPrint('[PinningClient] _extractPinsFromPem error: $e');
      return [];
    }
  }

  List<String> _pemToDerB64Blocks(String pem) {
    final regex = RegExp(
        r'-----BEGIN CERTIFICATE-----(.*?)-----END CERTIFICATE-----',
        dotAll: true);
    return regex.allMatches(pem).map((m) => m.group(1)!.trim()).toList();
  }

  /// Callback que valida el certificado presentado por el servidor.
  bool _verifyCert(X509Certificate cert, String host, int port) {
    try {
      if (host != pinnedHost) {
        debugPrint('[PinningClient] host $host != $pinnedHost, rechazado');
        return false;
      }
      final der = cert.der;
      final digest = sha256.convert(der);
      final pin = base64Encode(digest.bytes);
      final valid = _pins.contains(pin);
      if (valid) {
        debugPrint('[PinningClient] pin válido para $host:$port');
      } else {
        debugPrint(
            '[PinningClient] pin NO coincide para $host:$port — recibido: $pin, esperados: $_pins');
      }
      return valid;
    } catch (e) {
      debugPrint('[PinningClient] _verifyCert error: $e');
      return false;
    }
  }

  HttpClient _createHttpClient() {
    final client = HttpClient();
    client.badCertificateCallback = _verifyCert;
    client.connectionTimeout = _timeout;
    return client;
  }

  /// GET con pinning. Solo permite host `pirineosapi.ecomputer.es`.
  Future<http.Response> getPinned(Uri uri, {Map<String, String>? headers}) async {
    await _ensureInitialized();
    if (uri.host != pinnedHost) {
      debugPrint('[PinningClient] getPinned host no permitido: ${uri.host}');
      throw HttpException('Host no permitido para pinning: ${uri.host}');
    }
    HttpClient? ioClient;
    try {
      ioClient = _createHttpClient();
      final request = await ioClient.getUrl(uri);
      headers?.forEach((k, v) => request.headers.set(k, v));
      final ioResponse = await request.close().timeout(_timeout);
      final body = await ioResponse.fold<BytesBuilder>(
          BytesBuilder(), (b, d) => b..add(d)).then((b) => b.takeBytes());
      final response = http.Response.bytes(
        body,
        ioResponse.statusCode,
        headers: _httpHeadersToMap(ioResponse.headers),
        reasonPhrase: ioResponse.reasonPhrase,
      );
      debugPrint('[PinningClient] GET $uri -> ${response.statusCode}');
      return response;
    } catch (e) {
      debugPrint('[PinningClient] getPinned error $uri: $e');
      rethrow;
    } finally {
      try {
        ioClient?.close(force: true);
      } catch (e) {
        debugPrint('[PinningClient] close error: $e');
      }
    }
  }

  /// POST con pinning. Solo permite host `pirineosapi.ecomputer.es`.
  Future<http.Response> postPinned(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    await _ensureInitialized();
    if (uri.host != pinnedHost) {
      debugPrint('[PinningClient] postPinned host no permitido: ${uri.host}');
      throw HttpException('Host no permitido para pinning: ${uri.host}');
    }
    HttpClient? ioClient;
    try {
      ioClient = _createHttpClient();
      final request = await ioClient.postUrl(uri);
      headers?.forEach((k, v) => request.headers.set(k, v));
      if (body != null) {
        final bytes = _encodeBody(body, encoding);
        request.add(bytes);
      }
      final ioResponse = await request.close().timeout(_timeout);
      final respBytes = await ioResponse.fold<BytesBuilder>(
          BytesBuilder(), (b, d) => b..add(d)).then((b) => b.takeBytes());
      final response = http.Response.bytes(
        respBytes,
        ioResponse.statusCode,
        headers: _httpHeadersToMap(ioResponse.headers),
        reasonPhrase: ioResponse.reasonPhrase,
      );
      debugPrint('[PinningClient] POST $uri -> ${response.statusCode}');
      return response;
    } catch (e) {
      debugPrint('[PinningClient] postPinned error $uri: $e');
      rethrow;
    } finally {
      try {
        ioClient?.close(force: true);
      } catch (e) {
        debugPrint('[PinningClient] close error: $e');
      }
    }
  }

  List<int> _encodeBody(Object body, Encoding? encoding) {
    try {
      if (body is String) {
        return (encoding ?? utf8).encode(body);
      } else if (body is List<int>) {
        return body;
      } else if (body is Map) {
        return utf8.encode(jsonEncode(body));
      } else {
        return utf8.encode(body.toString());
      }
    } catch (e) {
      debugPrint('[PinningClient] _encodeBody error: $e');
      return utf8.encode(body.toString());
    }
  }

  Map<String, String> _httpHeadersToMap(HttpHeaders headers) {
    final map = <String, String>{};
    try {
      headers.forEach((name, values) {
        map[name] = values.join(',');
      });
    } catch (e) {
      debugPrint('[PinningClient] _httpHeadersToMap error: $e');
    }
    return map;
  }
}
