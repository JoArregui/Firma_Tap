import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EmpresaCard extends StatelessWidget {
  final String descripcion;

  const EmpresaCard({
    super.key,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                descripcion,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.2);
  }
}
