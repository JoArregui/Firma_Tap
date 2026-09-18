import 'package:flutter/material.dart';

Future<T?> navegarAnimado<T>(BuildContext context, Widget destino) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, _, _) => destino,
      transitionsBuilder: (_, anim, _, child) {
        final entrada = Tween<Offset>(
          begin: const Offset(1, 0), // desde la derecha
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));

        final salida = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.3, 0), // hacia la izquierda al volver
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeIn));

        return SlideTransition(
          position: anim.status == AnimationStatus.reverse ? salida : entrada,
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        );
      },
    ),
  );
}
