import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servicio de foto + geolocalización usando [image_picker], [geolocator] y [permission_handler].
///
/// - [pickPhoto] abre cámara con permisos.
/// - [getCurrentLocation] obtiene posición con permisos.
/// - [buildFotoFile] retorna [File] a partir de un path.
///
/// Lanza [Exception] descriptiva si permisos denegados. Usa [debugPrint].
class FotoGeoService {
  final ImagePicker _picker;

  FotoGeoService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Toma foto con la cámara. Solicita permiso de cámara antes.
  ///
  /// Retorna [XFile] si se tomó foto, `null` si el usuario canceló.
  /// Lanza [Exception] si permiso denegado / permanentemente denegado.
  Future<XFile?> pickPhoto() async {
    debugPrint('[FotoGeoService] pickPhoto() iniciado');

    // 1. Pedir permiso de cámara vía permission_handler
    final status = await Permission.camera.status;
    debugPrint('[FotoGeoService] Permission.camera status: $status');

    PermissionStatus newStatus = status;
    if (status.isDenied || status.isRestricted) {
      debugPrint('[FotoGeoService] Solicitando permiso de cámara...');
      newStatus = await Permission.camera.request();
      debugPrint('[FotoGeoService] Permission.camera tras request: $newStatus');
    }

    if (newStatus.isPermanentlyDenied) {
      debugPrint('[FotoGeoService] Permiso de cámara permanentemente denegado');
      throw Exception(
        'Permiso de cámara permanentemente denegado. Actívalo en Ajustes > Privacidad > Cámara.',
      );
    }

    if (!newStatus.isGranted) {
      debugPrint('[FotoGeoService] Permiso de cámara denegado: $newStatus');
      throw Exception(
        'Permiso de cámara denegado. Se requiere permiso de cámara para tomar fotos.',
      );
    }

    // 2. Lanzar cámara
    try {
      debugPrint('[FotoGeoService] Abriendo ImagePicker camera');
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      debugPrint('[FotoGeoService] pickPhoto result: ${photo?.path}');
      return photo;
    } catch (e) {
      debugPrint('[FotoGeoService] Error al tomar foto: $e');
      rethrow;
    }
  }

  /// Obtiene la ubicación actual. Pide permisos de localización antes.
  ///
  /// Verifica servicio habilitado, pide permiso con [permission_handler] y [Geolocator].
  /// Lanza [Exception] descriptiva si denegado o servicio deshabilitado.
  Future<Position> getCurrentLocation() async {
    debugPrint('[FotoGeoService] getCurrentLocation() iniciado');

    // 1. Servicio de ubicación habilitado
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('[FotoGeoService] isLocationServiceEnabled: $serviceEnabled');
    if (!serviceEnabled) {
      throw Exception(
        'Servicio de ubicación deshabilitado. Activa el GPS / Localización en ajustes del dispositivo.',
      );
    }

    // 2. Permission_handler para ubicación (whenInUse)
    final phStatus = await Permission.locationWhenInUse.status;
    debugPrint('[FotoGeoService] Permission.locationWhenInUse status: $phStatus');
    PermissionStatus phNewStatus = phStatus;
    if (phStatus.isDenied || phStatus.isRestricted) {
      debugPrint('[FotoGeoService] Solicitando permiso de ubicación (permission_handler)...');
      phNewStatus = await Permission.locationWhenInUse.request();
      debugPrint('[FotoGeoService] locationWhenInUse tras request: $phNewStatus');
    }

    if (phNewStatus.isPermanentlyDenied) {
      debugPrint('[FotoGeoService] Permiso de ubicación permanentemente denegado (permission_handler)');
      throw Exception(
        'Permiso de ubicación permanentemente denegado. Actívalo en Ajustes > Privacidad > Localización.',
      );
    }

    // 3. Geolocator check/request (doble verificación para iOS/Android)
    LocationPermission geoPermission = await Geolocator.checkPermission();
    debugPrint('[FotoGeoService] Geolocator.checkPermission: $geoPermission');
    if (geoPermission == LocationPermission.denied) {
      debugPrint('[FotoGeoService] Solicitando permiso Geolocator.requestPermission...');
      geoPermission = await Geolocator.requestPermission();
      debugPrint('[FotoGeoService] Geolocator.requestPermission result: $geoPermission');
    }

    if (geoPermission == LocationPermission.denied) {
      throw Exception(
        'Permiso de ubicación denegado. Se requiere permiso de ubicación para obtener la posición.',
      );
    }

    if (geoPermission == LocationPermission.deniedForever) {
      throw Exception(
        'Permiso de ubicación permanentemente denegado (Geolocator). Actívalo en Ajustes del sistema.',
      );
    }

    // 4. Obtener posición
    try {
      debugPrint('[FotoGeoService] Obteniendo Position con Geolocator.getCurrentPosition');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      debugPrint('[FotoGeoService] Position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('[FotoGeoService] Error getCurrentPosition: $e');
      rethrow;
    }
  }

  /// Construye un [File] a partir de [path]. No valida existencia por defecto,
  /// pero hace debugPrint y retorna [File].
  File buildFotoFile(String path) {
    debugPrint('[FotoGeoService] buildFotoFile path: $path');
    if (path.isEmpty) {
      throw Exception('Ruta de foto vacía: no se puede construir File');
    }
    final file = File(path);
    debugPrint('[FotoGeoService] File creado: ${file.path} exists=${file.existsSync()}');
    return file;
  }
}
