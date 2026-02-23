import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/empresa_dto.dart';

class EmpresaService {
  static Future<List<EmpresaDTO>> obtenerEmpresas() async {
    final response = await http.get(Uri.parse('https://pirineosapi.ecomputer.es/Empresa/GetEmpresas'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => EmpresaDTO.fromJson(e)).toList();
    } else {
      throw Exception('Error al cargar empresas');
    }
  }
}
