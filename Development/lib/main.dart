import 'package:flutter/material.dart';

import 'control/control_foco.dart';
import 'control/control_tarefa.dart';
import 'services/configuracoes_service.dart';
import 'services/notificacao_service.dart';
import 'telas/menu.dart';
import 'tema/tema_app.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.controleTarefa,
    this.controleFoco,
    this.configuracoesService,
    this.notificacaoService,
    this.relogio = DateTime.now,
  });

  final OperacoesTarefa? controleTarefa;
  final OperacoesFoco? controleFoco;
  final ConfiguracoesService? configuracoesService;
  final NotificacaoService? notificacaoService;
  final RelogioTarefa relogio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowTask',
      debugShowCheckedModeBanner: false,
      theme: TemaApp.claro,
      home: Menu(
        controleTarefa: controleTarefa,
        controleFoco: controleFoco,
        configuracoesService: configuracoesService,
        notificacaoService: notificacaoService,
        relogio: relogio,
      ),
    );
  }
}
