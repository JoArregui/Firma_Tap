class ClienteDto
{
  final int id;
  final String nombre;
  final String direccion;

  ClienteDto({required this.id, required this.nombre, required this.direccion});

  factory ClienteDto.fromJson(Map<String, dynamic> json) => ClienteDto(
    id: json['id'],
    nombre : json['nombre'],
    direccion: json['direccion'],
  );

}
