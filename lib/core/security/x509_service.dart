import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Servicio que simula firma X.509 y sellado de tiempo RFC 3161.
///
/// - [generarCsr]: genera un CSR mock (PKCS#10) base64 + clave privada simulada.
/// - [timestampRfc3161]: POST a TSA placeholder y retorna token mock (o real si responde).
/// - [verify]: verifica hash + firma mock.
class X509Service {
  static const String _tsaPlaceholderUrl = 'https://tsa.ecomputer.es/rfc3161';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _http;

  X509Service({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  /// Genera un CSR simulado (PKCS#10) y retorna mapa con `csrPem`, `privateKeyPem` y `publicKeyHash`.
  ///
  /// En producción reemplazar por `pointycastle` / platform channel con KeyStore/Keychain.
  Future<Map<String, String>> generarCsr({
    String commonName = 'CN=FirmaTap User',
    String organization = 'O=Ecomputer',
    String country = 'C=ES',
  }) async {
    try {
      final subject = '$country, $organization, $commonName';
      final timestamp = DateTime.now().toIso8601String();
      // Simulación: hash determinista como "clave"
      final seed = utf8.encode('$subject|$timestamp|${_randomHex(16)}');
      final privHash = sha256.convert(seed);
      final pubHash = sha256.convert(privHash.bytes);

      final csrDerMock = utf8.encode('CSR-MOCK|$subject|${base64Encode(pubHash.bytes)}');
      final csrPem = _toPem(csrDerMock, 'CERTIFICATE REQUEST');
      final privPem = _toPem(privHash.bytes, 'PRIVATE KEY');
      final pubHashB64 = base64Encode(pubHash.bytes);

      debugPrint('[X509Service] generarCsr subject:$subject pubHash:$pubHashB64');
      return {
        'csrPem': csrPem,
        'privateKeyPem': privPem,
        'publicKeyHash': pubHashB64,
        'subject': subject,
      };
    } catch (e, st) {
      debugPrint('[X509Service] generarCsr error: $e\n$st');
      rethrow;
    }
  }

  /// Solicita token RFC 3161 para [hash] (SHA256 del documento).
  ///
  /// Hace `POST` a TSA placeholder con `application/timestamp-query` (base64 del hash).
  /// Si el TSA no responde o no es RFC3161 real, retorna token mock con `hash`, `timestamp` y `nonce`.
  Future<Map<String, dynamic>> timestampRfc3161(Uint8List hash) async {
    try {
      final hashB64 = base64Encode(hash);
      final hashHex = hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      debugPrint('[X509Service] timestampRfc3161 hash(hex): $hashHex');

      // Intento real contra TSA placeholder
      try {
        final tsaUri = Uri.parse(_tsaPlaceholderUrl);
        final body = jsonEncode({
          'hash': hashB64,
          'hashAlgorithm': 'SHA256',
          'nonce': _randomHex(8),
        });
        final res = await _http
            .post(
              tsaUri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/timestamp-reply, application/json',
              },
              body: body,
            )
            .timeout(_timeout);

        debugPrint('[X509Service] TSA POST $tsaUri -> ${res.statusCode}');
        if (res.statusCode >= 200 && res.statusCode < 300) {
          // Si responde con JSON o bytes, envolver como token real
          final contentType = res.headers['content-type'] ?? '';
          if (contentType.contains('application/timestamp-reply')) {
            return {
              'status': 'ok',
              'source': 'tsa',
              'hash': hashB64,
              'token': base64Encode(res.bodyBytes),
              'contentType': contentType,
              'timestamp': DateTime.now().toUtc().toIso8601String(),
            };
          } else if (res.body.isNotEmpty) {
            try {
              final decoded = jsonDecode(res.body);
              return {
                'status': 'ok',
                'source': 'tsa',
                'hash': hashB64,
                'token': decoded is Map ? decoded['token'] ?? base64Encode(res.bodyBytes) : base64Encode(res.bodyBytes),
                'timestamp': DateTime.now().toUtc().toIso8601String(),
                'raw': decoded,
              };
            } catch (_) {
              return {
                'status': 'ok',
                'source': 'tsa',
                'hash': hashB64,
                'token': base64Encode(res.bodyBytes),
                'timestamp': DateTime.now().toUtc().toIso8601String(),
              };
            }
          }
        }
        debugPrint('[X509Service] TSA no disponible (${res.statusCode}), usando token mock');
      } catch (e) {
        debugPrint('[X509Service] TSA request falló, mock fallback: $e');
      }

      // Fallback token mock — determinista y verificable vía [verify]
      final nonce = _randomHex(8);
      final now = DateTime.now().toUtc().toIso8601String();
      final payload = utf8.encode('$hashB64|$now|$nonce|TSA-MOCK');
      final tokenDigest = sha256.convert(payload);
      final token = base64Encode(tokenDigest.bytes);

      final mock = {
        'status': 'mock',
        'source': 'mock',
        'hash': hashB64,
        'hashHex': hashHex,
        'token': token,
        'timestamp': now,
        'nonce': nonce,
        'policyOid': '1.3.6.1.4.1.99999.1.1',
        'tsa': _tsaPlaceholderUrl,
      };
      debugPrint('[X509Service] token mock generado: $token');
      return mock;
    } catch (e, st) {
      debugPrint('[X509Service] timestampRfc3161 error: $e\n$st');
      rethrow;
    }
  }

  /// Verifica firma/hash mock.
  ///
  /// [data] bytes originales, [signatureB64] firma base64, [hashB64] opcional.
  /// Para mock: verifica que sha256(data) coincida con hashB64 si se provee,
  /// y que signature no esté vacía.
  Future<bool> verify({
    required Uint8List data,
    required String signatureB64,
    String? hashB64,
    Map<String, dynamic>? timestampToken,
  }) async {
    try {
      if (signatureB64.isEmpty) {
        debugPrint('[X509Service] verify falló: firma vacía');
        return false;
      }
      final computedHash = sha256.convert(data);
      final computedB64 = base64Encode(computedHash.bytes);

      if (hashB64 != null && hashB64 != computedB64) {
        debugPrint('[X509Service] verify hash mismatch: esperado $hashB64 vs $computedB64');
        return false;
      }

      // Validar firma base64 decodificable
      try {
        final sig = base64Decode(signatureB64);
        if (sig.isEmpty) {
          debugPrint('[X509Service] verify firma decodificada vacía');
          return false;
        }
      } catch (e) {
        debugPrint('[X509Service] verify firma base64 inválida: $e');
        return false;
      }

      // Si hay token TSA, validar que el hash del token coincida
      if (timestampToken != null) {
        final tokenHash = timestampToken['hash'] as String?;
        if (tokenHash != null && tokenHash != computedB64) {
          debugPrint('[X509Service] verify TSA token hash mismatch: $tokenHash vs $computedB64');
          return false;
        }
        debugPrint('[X509Service] verify con token TSA ${timestampToken['timestamp']} ok');
      }

      debugPrint('[X509Service] verify ok hash:$computedB64 sig:${signatureB64.substring(0, 8)}...');
      return true;
    } catch (e, st) {
      debugPrint('[X509Service] verify error: $e\n$st');
      return false;
    }
  }

  /// Helpers

  String _toPem(List<int> der, String label) {
    final b64 = base64Encode(der);
    final chunks = RegExp(r'.{1,64}').allMatches(b64).map((m) => m.group(0)!).join('\n');
    return '-----BEGIN $label-----\n$chunks\n-----END $label-----';
  }

  String _randomHex(int bytes) {
    try {
      final now = DateTime.now().microsecondsSinceEpoch.toString();
      final digest = sha256.convert(utf8.encode(now));
      return digest.toString().substring(0, bytes * 2);
    } catch (e) {
      debugPrint('[X509Service] _randomHex error: $e');
      return '00' * bytes;
    }
  }

  void dispose() {
    try {
      _http.close();
    } catch (e) {
      debugPrint('[X509Service] dispose error: $e');
    }
  }
}
