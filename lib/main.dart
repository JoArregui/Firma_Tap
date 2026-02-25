import 'package:flutter/material.dart';
import 'features/pages/login_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Control de Albaranes',
      home: LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
