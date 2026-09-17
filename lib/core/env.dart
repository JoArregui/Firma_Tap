/// Configuración por entorno (dev/prod) sin hardcodear URLs en 3 sitios.
/// Usa --dart-define para sobreescribir en CI/CD o deja defaults.
/// Ejemplo: flutter run --dart-define=API_BASE=https://mi.api.com
class Env {
  static const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://10.0.2.2:5001/api');
  static const String documentoBaseUrl = String.fromEnvironment('DOCUMENTO_BASE_URL', defaultValue: 'https://pirineosapi.ecomputer.es/DocumentoAFirmar');

  static const String empresaUrl = String.fromEnvironment('EMPRESA_URL', defaultValue: 'https://pirineosapi.ecomputer.es/Empresa/GetEmpresas');

  static bool get isProd => const bool.fromEnvironment('PROD', defaultValue: true);
}
