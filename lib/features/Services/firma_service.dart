import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:signature/signature.dart';

class FirmaService {
  /// Convierte una firma del SignatureController a una imagen JPG en bytes
  static Future<Uint8List> convertirFirmaABytesJpg({
    required SignatureController controller,
  }) async
  {
    final Uint8List? pngBytes = await controller.toPngBytes(
    );
    if(pngBytes == null) throw Exception('No se pudo generar la imagen PNG');

    final img.Image? image = img.decodeImage(pngBytes);
    if(image == null) throw Exception('No se pudo decodificar la imagen PNG');

    return Uint8List.fromList(img.encodeJpg(image, quality: 60));
  }

  /// Envía la firma en formato JPG al servidor
  static Future<void> enviarFirma({
    required Uint8List jpgBytes,
    required String CodigoEmpresa,
    required String TipoDocumento,
    required int Numero,
    required String Usuario,
  }) async {
    final url = Uri.parse('https://pirineosapi.ecomputer.es/DocumentoAFirmar/SubirFirma');

    final request = http.MultipartRequest('POST', url)
      ..fields['CodigoEmpresa'] = CodigoEmpresa
      ..fields['TipoDocumento'] = TipoDocumento
      ..fields['Numero'] = Numero.toString()
      ..fields['Usuario'] = Usuario
      ..files.add(http.MultipartFile.fromBytes(
        'firma',
        jpgBytes,
        filename: '$Numero.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

    // No fijar Content-Type manualmente: http generará boundary correctamente
    request.headers['Accept'] = 'application/json';

    try {
      final stopwatch = Stopwatch()..start();

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          stopwatch.stop();
          throw TimeoutException('⏱️ Tiempo de espera agotado al enviar la firma tras ${stopwatch.elapsed.inSeconds} segundos');
        },
      );

      stopwatch.stop();
      debugPrint('⏱️ Tiempo de respuesta del servidor: ${stopwatch.elapsed.inSeconds} segundos');


      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode != 200) {
        throw Exception('Error ${streamedResponse.statusCode}: $responseBody');
      }
    } catch (e) {
      rethrow;
    }
  }
}


