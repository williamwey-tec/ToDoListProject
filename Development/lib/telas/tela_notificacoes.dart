import 'package:flutter/material.dart';

import '../tema/cores.dart';

/// Preferências de lembretes e notificações.
class TelaNotificacoes extends StatelessWidget {
  const TelaNotificacoes({super.key});

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
            Text('Notificações'),
            Text(
              'Lembretes no seu ritmo',
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
