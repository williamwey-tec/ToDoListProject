import 'dart:async';

import 'package:flutter/material.dart';

import '../control/control_foco.dart';
import '../model/tarefa.dart';
import '../tema/cores.dart';

/// Cronômetro e acompanhamento da tarefa em execução.
class TelaFoco extends StatefulWidget {
  const TelaFoco({
    super.key,
    required this.controleFoco,
    this.relogio = DateTime.now,
    this.revisaoTarefas = 0,
    this.onTarefasAlteradas,
  });

  final OperacoesFoco controleFoco;
  final RelogioFoco relogio;
  final int revisaoTarefas;
  final VoidCallback? onTarefasAlteradas;

  @override
  State<TelaFoco> createState() => _TelaFocoState();
}

class _TelaFocoState extends State<TelaFoco> {
  EstadoFoco? _estado;
  Timer? _atualizador;
  bool _carregando = true;
  bool _operando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _atualizador = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _estado?.estaEmAndamento == true) setState(() {});
    });
    _carregar();
  }

  @override
  void didUpdateWidget(covariant TelaFoco oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revisaoTarefas != widget.revisaoTarefas ||
        oldWidget.controleFoco != widget.controleFoco) {
      _carregar();
    }
  }

  @override
  void dispose() {
    _atualizador?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final estado = await widget.controleFoco.consultarEstado();
      if (!mounted) return;
      setState(() {
        _estado = estado;
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = _mensagemErro(erro);
      });
    }
  }

  Future<void> _executar(
    Future<EstadoFoco> Function() operacao, {
    bool alteraTarefa = false,
  }) async {
    if (_operando) return;
    setState(() {
      _operando = true;
      _erro = null;
    });
    try {
      final estado = await operacao();
      if (!mounted) return;
      setState(() {
        _estado = estado;
        _operando = false;
      });
      if (alteraTarefa) widget.onTarefasAlteradas?.call();
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _operando = false;
        _erro = _mensagemErro(erro);
      });
    }
  }

  String _mensagemErro(Object erro) {
    if (erro is FocoException) return erro.mensagem;
    if (erro is UnsupportedError) {
      return 'O modo Foco com tarefas salvas não está disponível no navegador.';
    }
    return 'Não foi possível atualizar o modo Foco. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    final estado = _estado;
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (_erro != null) _construirErro(),
          if (_erro != null) const SizedBox(height: 12),
          if (estado == null || !estado.possuiTarefa)
            _construirSelecaoVazia(estado)
          else ...[
            _construirCartaoFoco(estado),
            const SizedBox(height: 18),
            _construirAcoes(estado),
            const SizedBox(height: 22),
            _construirSeletor(estado),
          ],
          const SizedBox(height: 26),
          _construirProximas(estado?.proximasTarefas ?? const []),
        ],
      ),
    );
  }

  Widget _construirErro() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CoresApp.atrasadaFundo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: CoresApp.erro),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_erro!, style: const TextStyle(color: CoresApp.erro)),
          ),
        ],
      ),
    );
  }

  Widget _construirSelecaoVazia(EstadoFoco? estado) {
    final tarefas = estado?.tarefasDisponiveis ?? const <Tarefa>[];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CoresApp.principalSuave,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Icon(Icons.timer_outlined, color: CoresApp.principal, size: 52),
          const SizedBox(height: 12),
          const Text(
            'Escolha a tarefa do seu foco',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CoresApp.texto,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tarefas.isEmpty
                ? 'Não há tarefas disponíveis para hoje.'
                : 'O tempo continuará de onde você pausar.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: CoresApp.textoSecundario),
          ),
          if (tarefas.isNotEmpty) ...[
            const SizedBox(height: 20),
            _dropdownTarefas(tarefas: tarefas, selecionada: null),
          ],
        ],
      ),
    );
  }

  Widget _construirCartaoFoco(EstadoFoco estado) {
    final tarefa = estado.tarefa!;
    final utilizado = estado.tempoUtilizadoEm(widget.relogio());
    final estimado = tarefa.duracaoEstimada ?? Duration.zero;
    final progresso = estimado == Duration.zero
        ? 0.0
        : (utilizado.inMilliseconds / estimado.inMilliseconds).clamp(0.0, 1.0);
    final restante = estimado - utilizado;

    return Container(
      key: const Key('cartao_foco'),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: CoresApp.principalSuave,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Text(
            'TAREFA ATUAL · ${_formatarHorario(tarefa.horario)}',
            style: const TextStyle(
              color: CoresApp.principal,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tarefa.titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CoresApp.texto,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _chipPrioridade(tarefa.prioridade),
          const SizedBox(height: 18),
          SizedBox(
            width: 218,
            height: 218,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progresso,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    color: CoresApp.principal,
                    backgroundColor: const Color(0xFFD7D0EE),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      estado.estaEmAndamento
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: CoresApp.principal,
                    ),
                    Text(
                      _formatarCronometro(utilizado),
                      key: const Key('tempo_foco'),
                      style: const TextStyle(
                        color: CoresApp.texto,
                        fontSize: 42,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      estado.estaEmAndamento
                          ? 'Cronômetro em andamento'
                          : 'Cronômetro pausado',
                      style: const TextStyle(
                        color: CoresApp.principal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _resumoTempo('Estimado', estimado)),
              Expanded(
                child: _resumoTempo('Utilizado', utilizado, destaque: true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            restante.isNegative
                ? 'Tempo estimado excedido em ${_formatarDuracao(-restante)}'
                : 'Restam ${_formatarDuracao(restante)} do tempo estimado',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CoresApp.textoSecundario,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirAcoes(EstadoFoco estado) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('acao_iniciar_retomar'),
                onPressed: _operando || estado.estaEmAndamento
                    ? null
                    : () => _executar(
                        estado.tempoAcumulado == Duration.zero
                            ? widget.controleFoco.iniciar
                            : widget.controleFoco.retomar,
                      ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  estado.tempoAcumulado == Duration.zero
                      ? 'Iniciar'
                      : 'Retomar',
                ),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                key: const Key('acao_pausar'),
                onPressed: _operando || !estado.estaEmAndamento
                    ? null
                    : () => _executar(
                        widget.controleFoco.pausar,
                        alteraTarefa: true,
                      ),
                icon: const Icon(Icons.pause_rounded),
                label: const Text('Pausar'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('acao_concluir_foco'),
            onPressed: _operando
                ? null
                : () => _executar(
                    widget.controleFoco.concluirTarefa,
                    alteraTarefa: true,
                  ),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Concluir tarefa'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 52),
              side: const BorderSide(color: CoresApp.borda),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ao iniciar, o tempo continua de onde você parou.',
          textAlign: TextAlign.center,
          style: TextStyle(color: CoresApp.textoSecundario, fontSize: 12),
        ),
      ],
    );
  }

  Widget _construirSeletor(EstadoFoco estado) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tarefa em foco',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _dropdownTarefas(
          tarefas: estado.tarefasDisponiveis,
          selecionada: estado.tarefa?.identificador,
          habilitado: !_operando && !estado.estaEmAndamento,
        ),
      ],
    );
  }

  Widget _dropdownTarefas({
    required List<Tarefa> tarefas,
    required int? selecionada,
    bool habilitado = true,
  }) {
    return DropdownButtonFormField<int>(
      key: const Key('seletor_tarefa_foco'),
      initialValue: selecionada,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: CoresApp.superficie,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        hintText: 'Selecionar tarefa',
      ),
      items: tarefas
          .map(
            (tarefa) => DropdownMenuItem<int>(
              value: tarefa.identificador,
              child: Text(tarefa.titulo, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: habilitado
          ? (identificador) {
              if (identificador != null) {
                _executar(
                  () => widget.controleFoco.selecionarTarefa(identificador),
                );
              }
            }
          : null,
    );
  }

  Widget _construirProximas(List<Tarefa> tarefas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Depois do foco',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${tarefas.length} ${tarefas.length == 1 ? 'tarefa' : 'tarefas'}',
              style: const TextStyle(
                color: CoresApp.textoSecundario,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (tarefas.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CoresApp.superficie,
              border: Border.all(color: CoresApp.borda),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Nenhuma outra tarefa para hoje.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CoresApp.textoSecundario),
            ),
          )
        else
          ...tarefas.map(_cardProximaTarefa),
      ],
    );
  }

  Widget _cardProximaTarefa(Tarefa tarefa) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: CoresApp.superficie,
        border: Border.all(color: CoresApp.borda),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle_outlined, color: CoresApp.principal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatarHorario(tarefa.horario)} · '
                  '${_formatarDuracao(tarefa.duracaoEstimada ?? Duration.zero)}',
                  style: const TextStyle(
                    color: CoresApp.textoSecundario,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tarefa.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          _chipPrioridade(tarefa.prioridade, compacto: true),
        ],
      ),
    );
  }

  Widget _resumoTempo(
    String rotulo,
    Duration duracao, {
    bool destaque = false,
  }) {
    return Column(
      children: [
        Text(
          rotulo,
          style: const TextStyle(color: CoresApp.textoSecundario, fontSize: 12),
        ),
        const SizedBox(height: 3),
        Text(
          _formatarDuracao(duracao),
          style: TextStyle(
            color: destaque ? CoresApp.principal : CoresApp.texto,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _chipPrioridade(PrioridadeTarefa prioridade, {bool compacto = false}) {
    final (texto, cor, fundo) = switch (prioridade) {
      PrioridadeTarefa.baixa => (
        'Prioridade baixa',
        CoresApp.prioridadeBaixa,
        CoresApp.prioridadeBaixaFundo,
      ),
      PrioridadeTarefa.media => (
        'Prioridade média',
        CoresApp.prioridadeMedia,
        CoresApp.prioridadeMediaFundo,
      ),
      PrioridadeTarefa.alta => (
        'Prioridade alta',
        CoresApp.prioridadeAlta,
        CoresApp.prioridadeAltaFundo,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 8 : 10,
        vertical: compacto ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        compacto ? texto.replaceFirst('Prioridade ', '') : texto,
        style: TextStyle(
          color: cor,
          fontSize: compacto ? 10 : 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatarCronometro(Duration duracao) {
    final total = duracao.inSeconds < 0 ? 0 : duracao.inSeconds;
    final horas = total ~/ Duration.secondsPerHour;
    final minutos = (total ~/ Duration.secondsPerMinute) % 60;
    final segundos = total % 60;
    final mm = minutos.toString().padLeft(2, '0');
    final ss = segundos.toString().padLeft(2, '0');
    return horas > 0
        ? '${horas.toString().padLeft(2, '0')}:$mm:$ss'
        : '$mm:$ss';
  }

  String _formatarDuracao(Duration duracao) {
    final minutos = duracao.inMinutes;
    if (minutos >= 60) {
      final horas = minutos ~/ 60;
      final resto = minutos % 60;
      return resto == 0 ? '${horas}h' : '${horas}h ${resto}min';
    }
    if (minutos > 0) return '$minutos min';
    return '${duracao.inSeconds.clamp(0, 59)} s';
  }

  String _formatarHorario(HorarioTarefa? horario) {
    if (horario == null) return 'Sem horário';
    return '${horario.hora.toString().padLeft(2, '0')}:'
        '${horario.minuto.toString().padLeft(2, '0')}';
  }
}
