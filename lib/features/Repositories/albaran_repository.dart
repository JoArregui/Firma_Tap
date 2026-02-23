import 'package:app_control_albaranes/features/Services/albaran_service.dart';
import 'package:app_control_albaranes/features/models/Albaran_dto.dart';
import 'package:app_control_albaranes/features/models/documento_dto.dart';

import '../models/firma_dto.dart';

class AlbaranRepository
{
  final AlbaranService _albaranService = AlbaranService();

  Future<List<AlbaranDto>> obtenerPendientes() async
  {
   return _albaranService.getAlbaranesPendientes();
  }

  Future<void> firmarAlbaran(int id, FirmaDto firma)
  {
    return _albaranService.enviarFirma(id, firma);
  }

  Future<List<DocumentoDto>> obtenerDocumento(int albaranId, String empresa)
  {
    return _albaranService.obtenerDocumento(albaranId, empresa);
  }
}