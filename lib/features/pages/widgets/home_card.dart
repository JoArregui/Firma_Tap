import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum OptionHome{pendientes, albaranes }
class HomeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;


  const HomeCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 36, color: const Color.fromARGB(255,0,47,108)),
                const SizedBox(height: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 15, color: Color.fromARGB(255, 0, 47, 108), fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.2);
  }
}
