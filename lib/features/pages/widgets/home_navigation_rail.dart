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
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.description),
          label: Text("Pendientes"),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings),
          label: Text("Configuración"),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.close),
          label: Text("Cerrar app"),
        ),
      ],
    );
  }
}
