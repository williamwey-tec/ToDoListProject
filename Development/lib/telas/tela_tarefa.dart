import 'package:flutter/material.dart';

import '../tema/cores.dart';

/// Formulário de criação e edição de tarefas.
class TelaTarefa extends StatelessWidget {
  const TelaTarefa({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoresApp.fundo,
      appBar: AppBar(
        toolbarHeight: 76,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nova tarefa'),
            Text(
              'Reserve tempo para o que importa',
              style: TextStyle(
                color: CoresApp.textoSecundario,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: const SizedBox.shrink(),
    );
  }
}
