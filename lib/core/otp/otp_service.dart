import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../env.dart';
import '../network/api_client.dart';

/// Servicio OTP para solicitar y verificar códigos vía HTTP.
/// Usa `ApiClient` con timeout (15s por defecto) y `http` como transporte.
/// Endpoints:
/// - POST {Env.documentoBaseUrl}/SolicitarOTP  body {Telefono}
/// - POST {Env.documentoBaseUrl}/VerificarOTP  body {Telefono, Codigo}
class OtpService {
  final ApiClient _client;

  OtpService({ApiClient? client}) : _client = client ?? ApiClient();

  Uri get _solicitarUri => Uri.parse('${Env.documentoBaseUrl}/SolicitarOTP');
  Uri get _verificarUri => Uri.parse('${Env.documentoBaseUrl}/VerificarOTP');

  /// Solicita OTP al servidor para el teléfono dado.
  /// Retorna true si el servidor responde 2xx, false en caso contrario.
  /// Lanza [TimeoutException] si expira el timeout de [ApiClient].
  Future<bool> solicitarOtp(String telefono) async {
    if (telefono.trim().isEmpty) {
      throw ArgumentError('telefono no puede estar vacío');
    }
    try {
      debugPrint('[OtpService] solicitarOtp telefono=$telefono uri=$_solicitarUri');
      final res = await _client.post(
        _solicitarUri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'Telefono': telefono}),
      );
      debugPrint('[OtpService] solicitarOtp status=${res.statusCode} body=${res.body}');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return true;
      }
      throw Exception('Error solicitar OTP: HTTP ${res.statusCode} ${res.body}');
    } on TimeoutException catch (e) {
      debugPrint('[OtpService] solicitarOtp Timeout: $e');
      rethrow;
    } catch (e, st) {
      debugPrint('[OtpService] solicitarOtp Error: $e\n$st');
      rethrow;
    }
  }

  /// Verifica el código OTP para el teléfono dado.
  /// Retorna true si la verificación es exitosa (2xx + body indica ok).
  /// Lanza excepción si el código es inválido o hay error de red.
  Future<bool> verificarOtp(String telefono, String codigo) async {
    if (telefono.trim().isEmpty) {
      throw ArgumentError('telefono no puede estar vacío');
    }
    if (codigo.trim().isEmpty) {
      throw ArgumentError('codigo no puede estar vacío');
    }
    try {
      debugPrint('[OtpService] verificarOtp telefono=$telefono codigo=$codigo uri=$_verificarUri');
      final res = await _client.post(
        _verificarUri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'Telefono': telefono, 'Codigo': codigo}),
      );
      debugPrint('[OtpService] verificarOtp status=${res.statusCode} body=${res.body}');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Algunos backends devuelven {ok:true} o {verificado:true} o simplemente 200
        if (res.body.isEmpty) return true;
        try {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            if (decoded.containsKey('ok')) return decoded['ok'] == true;
            if (decoded.containsKey('verificado')) return decoded['verificado'] == true;
            if (decoded.containsKey('success')) return decoded['success'] == true;
            if (decoded.containsKey('valido')) return decoded['valido'] == true;
            // Si hay campo resultado sin wrap
            return true;
          }
          if (decoded is bool) return decoded;
          return true;
        } catch (_) {
          // Body no es JSON pero status es 2xx -> éxito
          return true;
        }
      }
      throw Exception('Error verificar OTP: HTTP ${res.statusCode} ${res.body}');
    } on TimeoutException catch (e) {
      debugPrint('[OtpService] verificarOtp Timeout: $e');
      rethrow;
    } catch (e, st) {
      debugPrint('[OtpService] verificarOtp Error: $e\n$st');
      rethrow;
    }
  }

  void close() => _client.close();
}
