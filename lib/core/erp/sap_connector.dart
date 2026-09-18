import 'dart:convert';

import 'package:app_control_albaranes/core/env.dart';
import 'package:app_control_albaranes/core/network/api_client.dart';
import 'package:flutter/foundation.dart';

class SapConnector {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> fetchAlbaranes({required String empresa}) async {
    final uri = Uri.parse('${Env.documentoBaseUrl}/Sap/Albaranes?empresa=$empresa');
    try {
      final response = await _api.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(jsonList);
      }
      return [];
    } catch (e) {
      debugPrint('SapConnector error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> postFirma(Map<String, dynamic> payload) async {
    final uri = Uri.parse('${Env.documentoBaseUrl}/Sap/Firma');
    try {
      final response = await _api.post(uri, body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('SapConnector postFirma error: $e');
      return null;
    }
  }
}