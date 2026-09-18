import 'package:firma_tap/features/repositories/albaran_repository.dart';
import 'package:firma_tap/features/pages/detalle_albaran_page.dart';
import 'package:flutter/material.dart';

import '../models/albaran_dto.dart';

class AlbaranPendientePage extends StatefulWidget {
  const AlbaranPendientePage({super.key});

  @override
  State<AlbaranPendientePage> createState() => _AlbaranPendientePageState();
}

class _AlbaranPendientePageState extends State<AlbaranPendientePage> {
  final AlbaranRepository albaranRepo = AlbaranRepository();
  late Future<List<AlbaranDto>> futureAlbaranes;
  
  @override
  void initState()
  {
    super.initState();
    futureAlbaranes = albaranRepo.obtenerPendientes();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arbaranes pendientes:'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: FutureBuilder<List<AlbaranDto>>(
          future: futureAlbaranes,
          builder: (context, snapshot)
          {
            if(snapshot.connectionState == ConnectionState.waiting)
            {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            
            if(snapshot.hasError)
            {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }

            final albaranes = snapshot.data!;
            return ListView.builder(
                itemCount: albaranes.length,
            itemBuilder: (context, index )
            {
              final a = albaranes[index];
              return ListTile(
                title: Text(a.numero),
                subtitle: Text('${a.cliente.nombre} - ${a.fecha.toLocal()}'),
                trailing: Text(a.estado),
                onTap: ()
                {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DetalleAlbaranPage(albaran: a),
                      ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
