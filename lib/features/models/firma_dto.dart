class CoordenadasFirma
{
  final int pagina;
  final double x;
  final double y;

  CoordenadasFirma({required this.pagina, required this.x, required this.y});

  Map<String, dynamic> toJson() => {
    'pagina' : pagina,
    'x' : x,
    'y' : y,
  };
}

class FirmaDto
{
  final String usuario;
  final String firmaBase64;
  final DateTime fechaFirma;
  final CoordenadasFirma coordenadas;
  final String observaciones;

  FirmaDto({
    required this.usuario,
    required this.firmaBase64,
    required this.fechaFirma,
    required this.coordenadas,
    required this.observaciones});

  Map<String, dynamic> toJson() => {
    'usuario' : usuario,
    'firmaBase64' : firmaBase64,
    'fechafirma' : fechaFirma.toIso8601String(),
    'coordenadas' : coordenadas.toJson(),
    'observaciones' : observaciones,
  };

}
