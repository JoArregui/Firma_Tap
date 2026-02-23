class DocumentoDto {
  final int id;
  final String? codigoEmpresa;
  final int usuario;
  final String? tipoDocumento;
  final int numero;
  final DateTime fecha;
  final double baseTotal;
  final double total;
  final bool firmado;
  final int largo;
  final int ancho;

  DocumentoDto({
    required this.id,
    required this.codigoEmpresa,
    required this.usuario,
    required this.tipoDocumento,
    required this.numero,
    required this.fecha,
    required this.baseTotal,
    required this.total,
    required this.firmado,
    required this.largo,
    required this.ancho,
  });

  factory DocumentoDto.fromJson(Map<String, dynamic> json) {
    return DocumentoDto(
      id: json['Id'],
      codigoEmpresa: json['CodigoEmpresa'],
      usuario: json['Usuario'] ?? 0,
      tipoDocumento: json['TipoDocumento'],
      numero: json['Numero'] ?? 0,
      fecha: DateTime.tryParse(json['Fecha'] ?? '') ?? DateTime(1970),
      baseTotal: (json['BaseTotal'] as num?)?.toDouble() ?? 0.0,
      total: (json['Total'] as num?)?.toDouble() ?? 0.0,
      firmado: json['Firmado'] ?? false,
      largo: json['Largo'] ?? 0,
      ancho: json['Ancho'] ?? 0,
    );
  }
}
