import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../../core/otp/otp_service.dart';

/// Página OTP con `Pinput` de 6 dígitos, timer 60s para reenvío y callback `onVerified`.
///
/// Uso:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(builder: (_) => OtpPage(
///   telefono: '612345678',
///   onVerified: () => Navigator.pop(context, true),
/// )));
/// ```
class OtpPage extends StatefulWidget {
  final String telefono;
  final VoidCallback onVerified;
  final OtpService? otpService;

  const OtpPage({
    super.key,
    required this.telefono,
    required this.onVerified,
    this.otpService,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  late final OtpService _otpService;
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocus = FocusNode();

  Timer? _timer;
  int _secondsRemaining = 60;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _otpService = widget.otpService ?? OtpService();
    _startTimer();
    debugPrint('[OtpPage] init telefono=${widget.telefono}');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _pinFocus.dispose();
    // No cerramos el client si fue inyectado desde fuera
    if (widget.otpService == null) {
      _otpService.close();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        t.cancel();
        setState(() => _secondsRemaining = 0);
        debugPrint('[OtpPage] Timer finalizado, reenvío habilitado');
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _resend() async {
    if (_secondsRemaining > 0 || _isResending) return;
    setState(() {
      _isResending = true;
      _errorText = null;
    });
    try {
      debugPrint('[OtpPage] Reenviando OTP a ${widget.telefono}');
      final ok = await _otpService.solicitarOtp(widget.telefono);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código reenviado')),
        );
        _startTimer();
      }
    } catch (e) {
      debugPrint('[OtpPage] Error reenvío: $e');
      if (mounted) {
        setState(() => _errorText = 'No se pudo reenviar: $e');
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verify(String code) async {
    if (code.length != 6 || _isVerifying) return;
    setState(() {
      _isVerifying = true;
      _errorText = null;
    });
    try {
      debugPrint('[OtpPage] Verificando OTP telefono=${widget.telefono} codigo=$code');
      final ok = await _otpService.verificarOtp(widget.telefono, code);
      if (!mounted) return;
      if (ok) {
        debugPrint('[OtpPage] OTP verificado con éxito');
        widget.onVerified();
      } else {
        setState(() => _errorText = 'Código incorrecto');
      }
    } catch (e) {
      debugPrint('[OtpPage] Error verificarOtp: $e');
      if (!mounted) return;
      setState(() => _errorText = 'Error al verificar: $e');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black),
      decoration: BoxDecoration(
        border: Border.all(color: const Color.fromRGBO(0, 47, 108, 0.3)),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: const Color.fromRGBO(0, 47, 108, 1)),
      borderRadius: BorderRadius.circular(10),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: const Color.fromRGBO(0, 47, 108, 0.05),
      ),
    );

    final canResend = _secondsRemaining == 0 && !_isResending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación OTP'),
        backgroundColor: const Color.fromARGB(255, 0, 47, 108),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.sms_outlined, size: 56, color: Color.fromARGB(255, 0, 47, 108)),
            const SizedBox(height: 16),
            Text(
              'Hemos enviado un código de 6 dígitos a',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              widget.telefono,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 47, 108)),
            ),
            const SizedBox(height: 28),
            Pinput(
              length: 6,
              controller: _pinController,
              focusNode: _pinFocus,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
              pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
              showCursor: true,
              onCompleted: _verify,
              onChanged: (v) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(_errorText!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isVerifying
                    ? null
                    : () => _verify(_pinController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 0, 47, 108),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isVerifying
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verificar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_secondsRemaining > 0)
                  Text('Reenviar código en $_secondsRemaining s',
                      style: TextStyle(color: Colors.grey.shade600)),
                if (_secondsRemaining == 0)
                  TextButton(
                    onPressed: canResend ? _resend : null,
                    child: _isResending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Reenviar código'),
                  ),
              ],
            ),
            if (_secondsRemaining == 0 && !_isResending)
              TextButton(
                onPressed: () => _pinController.clear(),
                child: const Text('Limpiar'),
              ),
          ],
        ),
      ),
    );
  }
}
