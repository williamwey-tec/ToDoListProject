import 'package:flutter/material.dart';

import 'control/control_tarefa.dart';
import 'telas/menu.dart';
import 'tema/tema_app.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.controleTarefa, this.relogio = DateTime.now});

  final OperacoesTarefa? controleTarefa;
  final RelogioTarefa relogio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowTask',
      debugShowCheckedModeBanner: false,
      theme: TemaApp.claro,
      home: Menu(controleTarefa: controleTarefa, relogio: relogio),
    );
  }
}
