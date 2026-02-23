
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
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isSaving = false;

  Future<void> _guardarFirmaDocumento() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, firma antes de continuar')),
      );
      return;
    }

    setState(() => _isSaving = true);


    print('🟡 Mostrando diálogo');
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
        print('🟢 Diálogo mostrado, convirtiendo firma');
        final jpgBytes = await FirmaService.convertirFirmaABytesJpg(
          controller: _controller,
        );

        // Enviar firma al servidor
        await FirmaService.enviarFirma(
            jpgBytes: jpgBytes,
            CodigoEmpresa: widget.documento.codigoEmpresa ?? 'Desconocido' ,
            TipoDocumento: widget.documento.tipoDocumento ?? 'Desconocido',
            Numero: widget.documento.numero,
            Usuario: widget.documento.usuario.toString(),
        );

        if(mounted){
          Navigator.of(context, rootNavigator: true).pop(); //Cerrar dialogo
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firma enviada correctamente')),
          );
          Navigator.pop(context, true); //Volver atrás
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
                const Text('FIRMA AQUI:', style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.5,
                ),
                ),
                Container(
                  width: doc.ancho.toDouble() * 100,
                  height: doc.largo.toDouble() * 4,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    color: Colors.grey[200],
                  ),
                  child: Signature(controller: _controller),
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
