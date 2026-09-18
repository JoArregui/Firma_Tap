import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class MorosidadPredictor {
  late Interpreter _interpreter;
  bool _initialized = false;
  late final Future<void> _initComplete;

  MorosidadPredictor() {
    _initComplete = _initialize();
  }

  Future<void> _initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/ml/morosidad.tflite');
      _initialized = true;
    } catch (e) {
      debugPrint('MorosidadPredictor init error: $e');
      _initialized = false;
    }
  }

  Future<double> predict(double total, int diasVencido) async {
    if (!_initialized) await _initComplete;
    if (!_initialized) return _heuristico(total, diasVencido);

    try {
      // Estructura de entrada esperada por el modelo: [1, 2] (2 features: total e diasVencido)
      final input = [
        [total / 1000.0, diasVencido.toDouble()]
      ];

      // Buffer de salida esperado por el modelo: [1, 1]
      final output = List.generate(1, (_) => List<double>.filled(1, 0.0));

      // Ejecución pasando entrada y buffer de salida
      _interpreter.run(input, output);

      final resultado = output[0][0];
      return (resultado * 100).toDouble();
    } catch (e) {
      debugPrint('MorosidadPredictor predict error: $e');
      return _heuristico(total, diasVencido);
    }
  }

  double _heuristico(double total, int diasVencido) {
    double riesgo = 0.0;
    if (diasVencido > 30) riesgo += 50.0;
    if (diasVencido > 60) riesgo += 30.0;
    if (total > 5000) riesgo += 20.0;
    return riesgo.clamp(0.0, 100.0);
  }

  Future<void> close() async {
    try {
      if (_initialized) {
        _interpreter.close();
      }
    } catch (_) {}
  }
}