import 'package:app_control_albaranes/features/pages/firma_documento_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/Albaran_dto.dart';
import '../models/documento_dto.dart';
import '../repositories/albaran_repository.dart';

class DocumentosPage extends StatefulWidget {
  final int usuarioId;
  final String empresa;

  const DocumentosPage({super.key, required this.usuarioId, required this.empresa});

  @override
  State<DocumentosPage> createState() => _DocumentosPageState();
}

class _DocumentosPageState extends State<DocumentosPage> {
  late Future<List<DocumentoDto>> futureDocumentos;


  @override
  void initState() {
    super.initState();
    _cargarDocumentos();
  }

  void _cargarDocumentos(){
    setState(() {
      futureDocumentos = AlbaranRepository().obtenerDocumento(widget.usuarioId, widget.empresa);
    });
  }

  bool _esDocVacio(DocumentoDto doc)
  {
    return doc.id == 0 &&
        (doc.codigoEmpresa == 'null' || doc.codigoEmpresa == null) &&
        (doc.tipoDocumento == 'null' || doc.tipoDocumento == null) &&
        doc.numero == 0;
  }

  Widget _buildSinDocumentos() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No hay documentos disponibles.'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _cargarDocumentos,
            icon: const Icon(Icons.refresh),
            label: const Text('Recargar'),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Documentos pendientes')),
      body: FutureBuilder<List<DocumentoDto>>(
        future: futureDocumentos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildSinDocumentos();
          }

          final documentos = snapshot.data!;
          if(documentos.length == 1 && _esDocVacio(documentos.first)){
            return const Center(child: Text('No hay Documentos disponibles.'));
          }

          return ListView.builder(
            itemCount: documentos.length,
            itemBuilder: (context, index) {
              final doc = documentos[index];
              return ListTile(
                title: Text('${doc.tipoDocumento ?? 'Documento'} Nº ${doc.numero}'),
                subtitle: Text('Total: ${doc.total.toStringAsFixed(2)} €'),
                trailing: Icon(Icons.arrow_circle_right
                ),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FirmaDocumentoPage(documento: doc),
                    ),
                  );

                  if (result == true){
                    _cargarDocumentos();
                    
                    //Mostrar SnackBar de confirmación
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Documento firmado correctamente'),
                      duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
