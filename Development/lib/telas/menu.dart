import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../control/control_tarefa.dart';
import '../model/tarefa.dart';
import '../services/banco_service.dart';
import '../tema/cores.dart';
import 'tela_calendario.dart';
import 'tela_foco.dart';
import 'tela_hoje.dart';
import 'tela_notificacoes.dart';
import 'tela_perfil.dart';
import 'tela_tarefa.dart';
import 'tela_tarefas_salvas.dart';

class _DestinoPrincipal {
  final String rotulo;
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final IconData iconeSelecionado;

  const _DestinoPrincipal({
    required this.rotulo,
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.iconeSelecionado,
  });
}

class _OperacoesTarefaIndisponiveis implements OperacoesTarefa {
  const _OperacoesTarefaIndisponiveis();

  Future<T> _indisponivel<T>() => Future<T>.error(
    UnsupportedError('SQLite não está disponível neste ambiente.'),
  );

  @override
  Future<Tarefa> criarTarefa(Tarefa tarefa) => _indisponivel();

  @override
  Future<Tarefa> editarTarefa(int identificador, Tarefa dadosEditados) =>
      _indisponivel();

  @override
  Future<Tarefa> concluirTarefa(int identificador) => _indisponivel();

  @override
  Future<Tarefa> reabrirTarefa(int identificador) => _indisponivel();

  @override
  Future<void> excluirTarefa(int identificador) => _indisponivel();

  @override
  Future<Tarefa?> consultarTarefaPorId(int identificador) => _indisponivel();

  @override
  Future<List<Tarefa>> consultarTarefasPorData(DateTime data) =>
      _indisponivel();

  @override
  Future<List<Tarefa>> consultarTarefasPorIntervalo(
    DateTime dataInicial,
    DateTime dataFinal,
  ) => _indisponivel();
}

/// Contêiner da navegação principal do FlowTask.
class Menu extends StatefulWidget {
  const Menu({super.key, this.controleTarefa, this.relogio = DateTime.now});

  final OperacoesTarefa? controleTarefa;
  final RelogioTarefa relogio;

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  int _indiceSelecionado = 0;
  late DateTime _dataSelecionadaCalendario;
  int _revisaoTarefas = 0;
  BancoService? _banco;
  OperacoesTarefa? _controleTarefa;

  static const List<_DestinoPrincipal> _destinos = [
    _DestinoPrincipal(
      rotulo: 'Hoje',
      titulo: 'Hoje',
      subtitulo: 'Planeje um dia de cada vez',
      icone: Icons.checklist_outlined,
      iconeSelecionado: Icons.checklist_rounded,
    ),
    _DestinoPrincipal(
      rotulo: 'Calendário',
      titulo: 'Calendário',
      subtitulo: 'Um dia de cada vez',
      icone: Icons.calendar_today_outlined,
      iconeSelecionado: Icons.calendar_today_rounded,
    ),
    _DestinoPrincipal(
      rotulo: 'Foco',
      titulo: 'Modo Foco',
      subtitulo: 'Menos distrações. Mais presença.',
      icone: Icons.timer_outlined,
      iconeSelecionado: Icons.timer_rounded,
    ),
    _DestinoPrincipal(
      rotulo: 'Perfil',
      titulo: 'Perfil',
      subtitulo: 'Seu espaço no FlowTask',
      icone: Icons.person_outline_rounded,
      iconeSelecionado: Icons.person_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final hoje = widget.relogio();
    _dataSelecionadaCalendario = DateTime(hoje.year, hoje.month, hoje.day);
  }

  OperacoesTarefa _obterControleTarefa() {
    final injetado = widget.controleTarefa;
    if (injetado != null) return injetado;

    final existente = _controleTarefa;
    if (existente != null) return existente;

    if (kIsWeb) {
      return _controleTarefa = const _OperacoesTarefaIndisponiveis();
    }

    final banco = BancoService();
    _banco = banco;
    return _controleTarefa = ControlTarefa(
      banco: banco,
      relogio: widget.relogio,
    );
  }

  void _informarBancoIndisponivel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'As tarefas salvas não estão disponíveis neste ambiente.',
        ),
      ),
    );
  }

  void _registrarAlteracaoTarefas() {
    if (mounted) setState(() => _revisaoTarefas++);
  }

  Future<void> _abrirNovaTarefa() async {
    try {
      final controle = _obterControleTarefa();
      final dataInicial = _indiceSelecionado == 1
          ? _dataSelecionadaCalendario
          : widget.relogio();
      final alterou = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) =>
              TelaTarefa(controleTarefa: controle, dataInicial: dataInicial),
        ),
      );
      if (alterou == true && mounted) {
        _registrarAlteracaoTarefas();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tarefa salva.')));
      }
    } catch (_) {
      if (mounted) _informarBancoIndisponivel();
    }
  }

  Future<void> _abrirTarefasSalvas() async {
    try {
      final controle = _obterControleTarefa();
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TelaTarefasSalvas(
            controleTarefa: controle,
            onTarefasAlteradas: _registrarAlteracaoTarefas,
          ),
        ),
      );
    } catch (_) {
      if (mounted) _informarBancoIndisponivel();
    }
  }

  void _abrirNotificacoes() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TelaNotificacoes()));
  }

  @override
  void dispose() {
    final banco = _banco;
    if (banco != null) unawaited(banco.fechar());
    super.dispose();
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
          if (permiteNovaTarefa)
            IconButton(
              onPressed: _abrirTarefasSalvas,
              icon: const Icon(
                Icons.inventory_2_outlined,
                color: CoresApp.principal,
              ),
              tooltip: 'Tarefas salvas',
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
        children: [
          TelaHoje(
            controleTarefa: _obterControleTarefa(),
            relogio: widget.relogio,
            revisaoTarefas: _revisaoTarefas,
            onTarefasAlteradas: _registrarAlteracaoTarefas,
            onNovaTarefa: _abrirNovaTarefa,
          ),
          TelaCalendario(
            controleTarefa: _obterControleTarefa(),
            relogio: widget.relogio,
            revisaoTarefas: _revisaoTarefas,
            onTarefasAlteradas: _registrarAlteracaoTarefas,
            onDataSelecionada: (data) {
              _dataSelecionadaCalendario = data;
            },
          ),
          const TelaFoco(),
          const TelaPerfil(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceSelecionado,
        onDestinationSelected: (indice) {
          setState(() {
            if ((indice == 0 || indice == 1) && indice != _indiceSelecionado) {
              _revisaoTarefas++;
            }
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
