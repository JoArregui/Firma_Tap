import 'package:app_control_albaranes/core/storage/auth_storage.dart';
import 'package:app_control_albaranes/core/utils/date_formatter.dart';
import 'package:flutter/material.dart';

import '../Repositories/albaran_repository.dart';
import '../models/Albaran_dto.dart';
import '../models/documento_dto.dart';

class DetalleAlbaranPage extends StatefulWidget {
  final AlbaranDto albaran;

  const DetalleAlbaranPage({super.key, required this.albaran});

  @override
  State<DetalleAlbaranPage> createState() => _DetalleAlbaranPageState();
}

class _DetalleAlbaranPageState extends State<DetalleAlbaranPage> {
  late Future<List<DocumentoDto>> futureDocumentos;

  @override
  void initState(){
    super.initState();
    // Carga empresa guardada; fallback EC para compatibilidad iOS/Android
    AuthStorage.getEmpresa().then((empresa) {
      final emp = (empresa != null && empresa.isNotEmpty) ? empresa : 'EC';
      setState(() {
        futureDocumentos = AlbaranRepository().obtenerDocumento(widget.albaran.id, emp);
      });
    });
    // provisional hasta que future se resuelva
    futureDocumentos = AlbaranRepository().obtenerDocumento(widget.albaran.id, 'EC');
  }

  @override
  Widget build(BuildContext context) {
    final albaran = widget.albaran;

    return Scaffold(
      appBar: AppBar(
        title: Text("Albaran ${albaran.numero}")
      ),
      body: Padding(padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cliente: ${widget.albaran.cliente.nombre}', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text("Dirección: ${widget.albaran.cliente.direccion}"),
          SizedBox(height: 8),
          Text("Fecha: ${DateFormatter.format(widget.albaran.fecha)}"),
          SizedBox(height: 8),
          Text("Estado: ${widget.albaran.estado}"),
          SizedBox(height: 24),
          Expanded(
              child: FutureBuilder<List<DocumentoDto>>(
                  future: futureDocumentos,
                  builder: (context, snapshot){
                    if(snapshot.connectionState == ConnectionState.waiting){
                      return Center(child: CircularProgressIndicator());
                    }else if(snapshot.hasError){
                      return Text('Error: ${snapshot.error}');
                    }else if(!snapshot.hasData || snapshot.data!.isEmpty){
                      return Text('No hay documentos disponibles');
                    }

                    final documentos = snapshot.data!;
                    return ListView.builder(
                        itemCount: documentos.length,
                        itemBuilder: (context, index){
                          final doc = documentos[index];
                          return Card(
                            child: ListTile(
                              title: Text('${doc.tipoDocumento} Nº ${doc.numero}'),
                              subtitle: Text('Total: ${doc.total.toStringAsFixed(2)} €'),
                              trailing: Icon(
                                doc.firmado ? Icons.check_circle : Icons.pending,
                                color: doc.firmado ? Colors.green : Colors.orange,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ),
          ],
        ),
      ),
    );
  }
}
