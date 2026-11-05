import 'package:flutter/material.dart';

import 'telas/menu.dart';
import 'tema/tema_app.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowTask',
      debugShowCheckedModeBanner: false,
      theme: TemaApp.claro,
      home: const Menu(),
    );
  }
}
