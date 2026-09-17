import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente HTTP central con timeout, manejo de errores y logging debug.
/// iOS/Android: añade timeout 15s por defecto y decodifica UTF-8.
class ApiClient {
  final http.Client _inner;
  final Duration timeout;

  ApiClient({http.Client? inner, this.timeout = const Duration(seconds: 15)}) : _inner = inner ?? http.Client();

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    try {
      final res = await _inner.get(url, headers: headers).timeout(timeout);
      return res;
    } on TimeoutException {
      throw TimeoutException('Tiempo de espera agotado (${timeout.inSeconds}s) para GET $url');
    }
  }

  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    try {
      final res = await _inner.post(url, headers: headers, body: body).timeout(timeout);
      return res;
    } on TimeoutException {
      throw TimeoutException('Tiempo de espera agotado (${timeout.inSeconds}s) para POST $url');
    }
  }

  static dynamic decodeJson(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  void close() => _inner.close();
}
