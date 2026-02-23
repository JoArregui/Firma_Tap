import 'package:app_control_albaranes/features/models/cliente_dto.dart';

class AlbaranDto
{
  final int id;
  final String numero;
  final DateTime fecha;
  final ClienteDto cliente;
  final String estado;
  final String pdfUrl;

  AlbaranDto({
    required this.id,
    required this.numero,
    required this.fecha,
    required this.cliente,
    required this.estado,
    required this.pdfUrl,
  });

  factory AlbaranDto.fromJson(Map<String, dynamic> json) => AlbaranDto(
    id: json['id'], 
    numero: json['numero'], 
    fecha: DateTime.parse(json['fecha']),
    cliente: ClienteDto.fromJson(json['cliente']), 
    estado: json['estado'],
    pdfUrl: json['pdfUrl'],
  );

  
}