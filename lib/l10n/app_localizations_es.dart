// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get login => 'Iniciar sesión';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get sign => 'Firmar';

  @override
  String get history => 'Historial';

  @override
  String get documents => 'Documentos';

  @override
  String get settings => 'Ajustes';

  @override
  String get search => 'Buscar';

  @override
  String get pending => 'Pendientes';

  @override
  String get signatureSuccess => 'Firma guardada correctamente';

  @override
  String get errorGeneric => 'Ha ocurrido un error';
}
