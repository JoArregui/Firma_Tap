import 'package:app_control_albaranes/core/env.dart';
import 'package:app_control_albaranes/core/network/api_client.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';

class WebhookService {
  final ApiClient _api = ApiClient();

  Future<void> notifyFirma({
    required String numero,
    required String hash,
    required String timestamp,
  }) async {
    final uri = Uri.parse(Env.webhookUrl);
    if (uri.host.isEmpty) {
      debugPrint('Webhook URL no configurada - saltando notificacion');
      return;
    }
    final payload = {
      'numero': numero,
      'hash': hash,
      'timestamp': timestamp,
      'evento': 'firma_completada',
    };
    try {
      final response = await _api.post(uri, body: jsonEncode(payload));
      debugPrint('Webhook response: ${response.statusCode}');
    } catch (e) {
      debugPrint('Webhook error: $e');
    }
  }
}