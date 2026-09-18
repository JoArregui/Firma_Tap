// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get login => 'Log in';

  @override
  String get logout => 'Log out';

  @override
  String get sign => 'Sign';

  @override
  String get history => 'History';

  @override
  String get documents => 'Documents';

  @override
  String get settings => 'Settings';

  @override
  String get search => 'Search';

  @override
  String get pending => 'Pending';

  @override
  String get signatureSuccess => 'Signature saved successfully';

  @override
  String get errorGeneric => 'An error has occurred';
}
