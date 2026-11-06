import 'package:flutter/material.dart';

import '../tema/cores.dart';
import 'tela_calendario.dart';
import 'tela_foco.dart';
import 'tela_hoje.dart';
import 'tela_notificacoes.dart';
import 'tela_perfil.dart';
import 'tela_tarefa.dart';

class _DestinoPrincipal {
  final String rotulo;
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final IconData iconeSelecionado;
  final Widget tela;

  const _DestinoPrincipal({
    required this.rotulo,
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.iconeSelecionado,
    required this.tela,
  });
}

/// Contêiner da navegação principal do FlowTask.
class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  int _indiceSelecionado = 0;

  static const List<_DestinoPrincipal> _destinos = [
    _DestinoPrincipal(
      rotulo: 'Hoje',
      titulo: 'Hoje',
      subtitulo: 'Planeje um dia de cada vez',
      icone: Icons.checklist_outlined,
      iconeSelecionado: Icons.checklist_rounded,
      tela: TelaHoje(),
    ),
    _DestinoPrincipal(
      rotulo: 'Calendário',
      titulo: 'Calendário',
      subtitulo: 'Um dia de cada vez',
      icone: Icons.calendar_today_outlined,
      iconeSelecionado: Icons.calendar_today_rounded,
      tela: TelaCalendario(),
    ),
    _DestinoPrincipal(
      rotulo: 'Foco',
      titulo: 'Modo Foco',
      subtitulo: 'Menos distrações. Mais presença.',
      icone: Icons.timer_outlined,
      iconeSelecionado: Icons.timer_rounded,
      tela: TelaFoco(),
    ),
    _DestinoPrincipal(
      rotulo: 'Perfil',
      titulo: 'Perfil',
      subtitulo: 'Seu espaço no FlowTask',
      icone: Icons.person_outline_rounded,
      iconeSelecionado: Icons.person_rounded,
      tela: TelaPerfil(),
    ),
  ];

  void _abrirNovaTarefa() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TelaTarefa()));
  }

  void _abrirNotificacoes() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TelaNotificacoes()));
  }

  @override
  Widget build(BuildContext context) {
    final destinoAtual = _destinos[_indiceSelecionado];
    final permiteNovaTarefa =
        _indiceSelecionado == 0 || _indiceSelecionado == 1;

    return Scaffold(
      backgroundColor: CoresApp.fundo,
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              destinoAtual.titulo,
              style: const TextStyle(
                color: CoresApp.texto,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              destinoAtual.subtitulo,
              style: const TextStyle(
                color: CoresApp.textoSecundario,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (permiteNovaTarefa)
            IconButton(
              onPressed: _abrirNovaTarefa,
              style: IconButton.styleFrom(
                backgroundColor: CoresApp.principalSuave,
                shape: const CircleBorder(),
              ),
              icon: const Icon(Icons.add_rounded, color: CoresApp.principal),
              tooltip: 'Nova tarefa',
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 12),
            child: IconButton(
              onPressed: _abrirNotificacoes,
              style: IconButton.styleFrom(
                backgroundColor: CoresApp.principalSuave,
                shape: const CircleBorder(),
              ),
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: CoresApp.principal,
              ),
              tooltip: 'Notificações',
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _indiceSelecionado,
        children: _destinos.map((destino) => destino.tela).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceSelecionado,
        onDestinationSelected: (indice) {
          setState(() {
            _indiceSelecionado = indice;
          });
        },
        destinations: _destinos
            .map(
              (destino) => NavigationDestination(
                icon: Icon(destino.icone),
                selectedIcon: Icon(destino.iconeSelecionado),
                label: destino.rotulo,
              ),
            )
            .toList(),
      ),
    );
  }
}
