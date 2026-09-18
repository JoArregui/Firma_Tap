import 'dart:convert';

import 'package:firma_tap/core/constants/api_constants.dart';
import 'package:firma_tap/features/models/albaran_dto.dart';
import 'package:firma_tap/features/models/documento_dto.dart';
import 'package:http/http.dart' as http;

import '../models/firma_dto.dart';
class AlbaranService
{
  final String _baseUrl = ApiConstants.baseUrl;

  Future<List<AlbaranDto>> getAlbaranesPendientes() async 
  {
    final response = await http.get(Uri.parse('$_baseUrl/albaranes/pendientes'));

    if(response.statusCode == 200)
    {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => AlbaranDto.fromJson(json)).toList(); 
    }
    else
    {
      throw Exception('Error al obtener albaranes');
    }
  }

  Future<void> enviarFirma(int albaranId, FirmaDto firma) async{
    final url = Uri.parse('$_baseUrl/albaranes/$albaranId/firmar');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(firma.toJson()),
    ).timeout(const Duration(seconds: 20));

    if(response.statusCode != 200)
    {
      throw Exception('Error al firmar el albarán: ${response.statusCode}');
    }
  }

  Future<List<DocumentoDto>> obtenerDocumento(int usuarioId, String empresa) async{
    final url = Uri.parse('${ApiConstants.documentoBaseUrl}/GetDocumentos/$usuarioId/$empresa');
    final response = await http.get(url);

    if(response.statusCode == 200)
    {
      final data = jsonDecode(response.body);

      if(data is List)
      {
        return data.map((json) => DocumentoDto.fromJson(json)).toList();
      }else if(data is Map<String, dynamic>)
      {
        return [DocumentoDto.fromJson(data)];
      }else
      {
        throw Exception('Formato de respuesta inesperado');
      }
    }else
    {
      throw Exception('Error al obtener documentos');
    }
  }

}
