class EmpresaDTO {
  final String codigo;
  final String descripcion;

  EmpresaDTO({required this.codigo, required this.descripcion});

  factory EmpresaDTO.fromJson(Map<String, dynamic> json) {
    return EmpresaDTO(
      codigo: json['Codigo'],
      descripcion: json['Descripcion'],
    );
  }
}
