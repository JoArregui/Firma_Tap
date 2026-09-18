import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pinput/pinput.dart';

/// Página de PIN fallback (4 dígitos) usando `pinput` + `flutter_secure_storage`.
///
/// - Si no existe `pin_code` en secure storage, entra en modo creación:
///   pide crear PIN y confirmarlo.
/// - Si existe, valida contra el valor guardado.
/// - `onSuccess` se invoca tras validación/creación exitosa.
///   El llamante debe comprobar `mounted` antes de navegar si usa `context` tras el callback.
///
/// Maneja `PlatformException` en lecturas/escrituras y respeta `mounted`.
class PinPage extends StatefulWidget {
  const PinPage({
    super.key,
    required this.onSuccess,
  });

  /// Callback invocado al validar/crear PIN correctamente.
  final VoidCallback onSuccess;

  @override
  State<PinPage> createState() => _PinPageState();
}

class _PinPageState extends State<PinPage> {
  static const _kPinCode = 'pin_code';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _loading = true;
  bool _isCreationMode = false;
  bool _isConfirmStep = false;
  String? _firstPin;
  String? _storedPin;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    try {
      final stored = await _storage.read(key: _kPinCode);
      if (!mounted) return;
      setState(() {
        _storedPin = stored;
        _isCreationMode = stored == null;
        _isConfirmStep = false;
        _firstPin = null;
        _loading = false;
      });
      debugPrint('[PinPage] loadPin isCreationMode=$_isCreationMode');
    } on PlatformException catch (e) {
      debugPrint('[PinPage] loadPin PlatformException: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = 'Error al leer PIN';
      });
    } catch (e) {
      debugPrint('[PinPage] loadPin error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = 'Error inesperado';
      });
    }
  }

  Future<void> _savePin(String pin) async {
    try {
      await _storage.write(key: _kPinCode, value: pin);
      debugPrint('[PinPage] savePin ok');
    } on PlatformException catch (e) {
      debugPrint('[PinPage] savePin PlatformException: $e');
      if (!mounted) return;
      setState(() => _errorText = 'No se pudo guardar el PIN');
      return;
    }
    if (!mounted) return;
    widget.onSuccess();
  }

  void _onCompleted(String pin) async {
    if (!mounted) return;
    setState(() => _errorText = null);

    // Modo creación
    if (_isCreationMode) {
      if (!_isConfirmStep) {
        // Primer paso: guardar temporal y pedir confirmación
        setState(() {
          _firstPin = pin;
          _isConfirmStep = true;
          _errorText = null;
        });
        _pinController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Confirma tu PIN')),
          );
        }
        return;
      } else {
        // Segundo paso: confirmar
        if (pin == _firstPin) {
          await _savePin(pin);
        } else {
          setState(() {
            _errorText = 'Los PIN no coinciden. Inténtalo de nuevo.';
            _firstPin = null;
            _isConfirmStep = false;
          });
          _pinController.clear();
        }
        return;
      }
    }

    // Modo validación
    if (pin == _storedPin) {
      widget.onSuccess();
    } else {
      setState(() => _errorText = 'PIN incorrecto');
      _pinController.clear();
      // Vibración háptica opcional
      try {
        await HapticFeedback.vibrate();
      } on PlatformException catch (e) {
        debugPrint('[PinPage] haptic PlatformException: $e');
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
    );
    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Theme.of(context).colorScheme.primary),
      borderRadius: BorderRadius.circular(8),
    );
    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      ),
    );
    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Theme.of(context).colorScheme.error),
      borderRadius: BorderRadius.circular(8),
    );

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String title = _isCreationMode
        ? (_isConfirmStep ? 'Confirma tu PIN' : 'Crea tu PIN')
        : 'Introduce tu PIN';
    final String subtitle = _isCreationMode
        ? (_isConfirmStep ? 'Repite el PIN de 4 dígitos' : 'Elige un PIN de 4 dígitos')
        : 'PIN de 4 dígitos para acceder';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              Pinput(
                length: 4,
                controller: _pinController,
                focusNode: _focusNode,
                obscureText: true,
                obscuringCharacter: '•',
                closeKeyboardWhenCompleted: true,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                submittedPinTheme: submittedPinTheme,
                errorPinTheme: errorPinTheme,
                forceErrorState: _errorText != null,
                errorText: _errorText,
                pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                onCompleted: _onCompleted,
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              if (_isCreationMode && _isConfirmStep)
                TextButton(
                  onPressed: () {
                    if (!mounted) return;
                    setState(() {
                      _firstPin = null;
                      _isConfirmStep = false;
                      _errorText = null;
                    });
                    _pinController.clear();
                  },
                  child: const Text('Volver a crear'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
