import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firma_tap/core/storage/history_service.dart';

class MapaEntregasPage extends StatefulWidget {
  const MapaEntregasPage({super.key});

  @override
  State<MapaEntregasPage> createState() => _MapaEntregasPageState();
}

class _MapaEntregasPageState extends State<MapaEntregasPage> {
  GoogleMapController? _controller;
  Set<Marker> _marcadores = {};
  List<Map<String, dynamic>> _albaranes = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarAlbaranes();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _cargarAlbaranes() async {
    final lista = await HistoryService.getAll();
    if (!mounted) return;

    setState(() {
      _albaranes = lista.map((e) {
        double totalCalculado = 0.0;
        if (e.hash.length >= 4) {
          final subStr = e.hash.substring(0, 4).replaceAll(' ', '');
          totalCalculado = double.tryParse(subStr) ?? 0.0;
        }

        return {
          'numero': e.numero,
          'total': totalCalculado,
          'lat': e.lat ?? 0.0,
          'lng': e.lng ?? 0.0,
        };
      }).toList();

      _marcadores = _generarMarcadores(_albaranes);
      _cargando = false;
    });
  }

  Set<Marker> _generarMarcadores(List<Map<String, dynamic>> lista) {
    final Set<Marker> marcadores = {};
    for (var i = 0; i < lista.length; i++) {
      final item = lista[i];
      final lat = item['lat'] as double?;
      final lng = item['lng'] as double?;
      final numero = item['numero'] as int?;
      final total = item['total'] as double?;

      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        marcadores.add(
          Marker(
            markerId: MarkerId('albaran_$i'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: 'Albarán $numero',
              snippet: 'Total: ${total?.toStringAsFixed(2) ?? "0.00"} €',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      }
    }
    return marcadores;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de Entregas')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(40.4168, -3.7038),
                zoom: 6,
              ),
              markers: _marcadores,
              onMapCreated: (GoogleMapController controller) {
                _controller = controller;
              },
            ),
    );
  }
}
