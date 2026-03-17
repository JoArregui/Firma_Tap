import 'package:flutter/material.dart';

class HomeNavigationRail extends StatelessWidget {
  final Function(int index) onSelect;

  const HomeNavigationRail({
    super.key,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: 0,
      onDestinationSelected: onSelect,
      labelType: NavigationRailLabelType.all,
      backgroundColor: Colors.white,

      groupAlignment: -1,
        leading: Column(
          children: const [
            SizedBox(height: 8),
          ],
        ),

      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.description),
          label: Text("Pendientes"),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings),
          label: Text("Configuración"),
        ),
      ],

      trailing: Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => onSelect(99),
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text(
                "Cerrar app",
                style: TextStyle(color: Colors.black),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),

    );
  }
}
