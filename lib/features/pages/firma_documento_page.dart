
import 'package:app_control_albaranes/core/media/foto_geo_service.dart';
import 'package:app_control_albaranes/core/offline/queue_service.dart';
import 'package:app_control_albaranes/core/storage/history_service.dart';
import 'package:app_control_albaranes/features/Services/firma_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import '../models/documento_dto.dart';

class FirmaDocumentoPage extends StatefulWidget {
  final DocumentoDto documento;

  const FirmaDocumentoPage({super.key, required this.documento});

  @override
  State<FirmaDocumentoPage> createState() => _FirmaDocumentoPageState();
}

class _FirmaDocumentoPageState extends State<FirmaDocumentoPage> {
  late SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isSaving = false;
  final FotoGeoService _fotoGeo = FotoGeoService();
  String? _fotoPath;
  double _lat = 0, _lng = 0;
  double _strokeWidth = 3; // Apple Pencil presión simulada con slider

  Future<void> _pickFoto() async {
    try {
      final x = await _fotoGeo.pickPhoto();
      if (x != null && mounted) setState(() => _fotoPath = x.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Foto: $e')));
    }
  }

  Future<void> _captureGeo() async {
    try {
      final pos = await _fotoGeo.getCurrentLocation();
      if (mounted) setState(() { _lat = pos.latitude; _lng = pos.longitude; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📍 ${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ubicación: $e')));
    }
  }

  Future<void> _guardarFirmaDocumento() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, firma antes de continuar')),
      );
      return;
    }

    setState(() => _isSaving = true);


    debugPrint('🟡 Mostrando diálogo');
    //Mostrar dialogo de carga
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Enviando firma...')),
            ],
          ),
        ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async{
      try
      {
        // Convertir firma a JPG
        debugPrint('🟢 Diálogo mostrado, convirtiendo firma');
        final jpgBytes = await FirmaService.convertirFirmaABytesJpg(
          controller: _controller,
        );

        // Capturar geolocalización (no bloqueante, fallback 0,0)
        try { final pos = await _fotoGeo.getCurrentLocation(); _lat = pos.latitude; _lng = pos.longitude; } catch (_) {}
        // Enviar firma al servidor
        try {
          await FirmaService.enviarFirma(
              jpgBytes: jpgBytes,
              CodigoEmpresa: widget.documento.codigoEmpresa ?? 'Desconocido' ,
              TipoDocumento: widget.documento.tipoDocumento ?? 'Desconocido',
              Numero: widget.documento.numero,
              Usuario: widget.documento.usuario.toString(),
          );
          // Historial local
          try { await HistoryService.addWithBytes(numero: widget.documento.numero, tipoDocumento: widget.documento.tipoDocumento ?? '-', empresa: widget.documento.codigoEmpresa ?? 'Desconocido', usuario: widget.documento.usuario.toString(), jpgBytes: jpgBytes, lat: _lat, lng: _lng); } catch (_) {}
          if(mounted){
            Navigator.of(context, rootNavigator: true).pop(); //Cerrar dialogo
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Firma enviada correctamente')),
            );
            Navigator.pop(context, true); //Volver atrás
          }
        } catch (e) {
          // Offline → encola
          await QueueService.enqueue(FirmaPendiente.fromBytes(codigoEmpresa: widget.documento.codigoEmpresa ?? 'Desconocido', tipoDocumento: widget.documento.tipoDocumento ?? 'Desconocido', numero: widget.documento.numero, usuario: widget.documento.usuario.toString(), jpgBytesRaw: jpgBytes, fotoPath: _fotoPath, lat: _lat, lng: _lng));
          if(mounted){
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📡 Sin conexión: firma encolada para ${widget.documento.numero}')));
            Navigator.pop(context, true);
          }
          return;
        }
      }catch(e){
        if(Navigator.of(context, rootNavigator: true).canPop()){
          Navigator.of(context, rootNavigator: true).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                'Error al guardar la firma: \n$e',
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            duration: const Duration(seconds: 6),
          ),
        );
      }finally{
        setState(() => _isSaving = false);
      }
    });
  }

  @override
  void initState(){
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.documento;
    final esHorizontal = MediaQuery.of(context).orientation == Orientation.landscape;

   /*
    vista original de Firma Documento
    return Scaffold(
      appBar: AppBar(
        title: Text('${doc.tipoDocumento} Nº ${doc.numero}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tip. Doc.: ${doc.tipoDocumento}'),
            //Text('Nº: ${doc.numero}'),
            Text('Fecha: ${formatoFecha.format(doc.fecha)}'),
            Text('Hora: $horaActual'),
            Text('Base: ${doc.baseTotal.toStringAsFixed(2)} €'),
            Text('Total: ${doc.total.toStringAsFixed(2)} €'),
            const SizedBox(height: 20),
            const Text('Firma aquí:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                color: Colors.grey[200],
                child: Signature(controller: _controller),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _controller.clear,
                    icon: const Icon(Icons.clear),
                    label: const Text('Borrar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:_isSaving ? null : _guardarFirmaDocumento,
                    icon: const Icon(Icons.check),
                    label: const Text('Guardar firma'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );*/

    //Vista sugerida por Jesus
    return Scaffold(
      appBar: AppBar(
          title: const Text('Firmar documento')),
      body: esHorizontal ? _buildFirmaHorizontal() : _buildMensajeVertical(),
    );
  }

  Widget _buildFirmaHorizontal(){
    final doc = widget.documento;
    final formatoFecha = DateFormat('dd/MM/yyyy');
    final horaActual = DateFormat('HH:mm').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(16),
      child:Row(
        children: [
          //Area de datos
          Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,

                children: [
                  Text('Documento: ${doc.tipoDocumento}'),
                  Text('Nº: ${doc.numero}'),
                  Text('Fecha: ${formatoFecha.format(doc.fecha)}'),
                  Text('Hora: $horaActual'),
                  Text('Base: ${doc.baseTotal.toStringAsFixed(2)} €'),
                  Text('Total: ${doc.total.toStringAsFixed(2)} €'),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _guardarFirmaDocumento,
                        icon: Icon(Icons.check),
                        label: const Text('Guardar Firma'),
                      ),
                      const SizedBox(width: 20),
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ],
              ),
          ),
          const SizedBox(width: 16),
          //Area de firma
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('FIRMA AQUI:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5)),
                    const SizedBox(width: 12),
                    Icon(Icons.edit, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('Apple Pencil OK', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                ),
                if (_fotoPath != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('📸 ${ _fotoPath!.split('/').last}', style: const TextStyle(color: Colors.green, fontSize: 10), overflow: TextOverflow.ellipsis)),
                if (_lat != 0) Text('📍 ${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final hasSize = doc.ancho > 0 && doc.largo > 0 && doc.ancho < 500 && doc.largo < 500;
                    double w = hasSize ? (doc.ancho.toDouble() * 4).clamp(280, 600) : 500;
                    double h = hasSize ? (doc.largo.toDouble() * 4).clamp(120, 280) : 220;
                    if (constraints.maxWidth.isFinite) w = w.clamp(0, constraints.maxWidth);
                    return Container(
                      width: w,
                      height: h,
                      decoration: BoxDecoration(border: Border.all(color: Colors.black), color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Signature(controller: _controller, backgroundColor: Colors.white)),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.brush, size: 14),
                    Expanded(child: Slider(value: _strokeWidth, min: 1, max: 6, divisions: 5, label: _strokeWidth.toStringAsFixed(1), onChanged: (v) { final oldEmpty = _controller.isEmpty; _controller.dispose(); setState(() { _strokeWidth = v; _controller = SignatureController(penStrokeWidth: _strokeWidth, penColor: Colors.black, exportBackgroundColor: Colors.white); if (!oldEmpty) {} }); })),
                    IconButton(icon: const Icon(Icons.camera_alt, size: 18), tooltip: 'Foto entrega', onPressed: _pickFoto),
                    IconButton(icon: const Icon(Icons.location_on, size: 18), tooltip: 'Ubicación', onPressed: _captureGeo),
                    IconButton(icon: const Icon(Icons.clear, size: 18), tooltip: 'Borrar', onPressed: () => _controller.clear()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ) ,
    );
  }

  Widget _buildMensajeVertical()
  {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Por Favor, gira el dispositivo para firmar en horizontal.',
          style: TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
