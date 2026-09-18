// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Catalan Valencian (`ca`).
class AppLocalizationsCa extends AppLocalizations {
  AppLocalizationsCa([String locale = 'ca']) : super(locale);

  @override
  String get login => 'Iniciar sessió';

  @override
  String get logout => 'Tancar sessió';

  @override
  String get sign => 'Signar';

  @override
  String get history => 'Historial';

  @override
  String get documents => 'Documents';

  @override
  String get settings => 'Ajustaments';

  @override
  String get search => 'Cercar';

  @override
  String get pending => 'Pendents';

  @override
  String get signatureSuccess => 'Signatura desada correctament';

  @override
  String get errorGeneric => 'S\'ha produït un error';
}
