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
      backgroundColor: Colors.indigo.shade50,

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

      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(Icons.close, color: Colors.red),
            onPressed: () => onSelect(99),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
