import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../control/control_tarefa.dart';
import '../model/tarefa.dart';
import '../services/configuracoes_service.dart';
import '../tema/cores.dart';
import '../widgets/card_tarefa.dart';
import '../widgets/indicador_progresso.dart';
import 'tela_tarefa.dart';

enum _PeriodoDia { manha, tarde, noite }

/// Planejamento do dia civil atual, conectado às tarefas persistidas.
///
/// Os períodos usam limites simples e previsíveis: manhã vai de 00:00 a
/// 11:59, tarde de 12:00 a 17:59 e noite de 18:00 a 23:59. Embora o formulário
/// atual exija horário, registros antigos sem horário continuam suportados e
/// aparecem no fim de Noite, depois de todas as tarefas com horário.
class TelaHoje extends StatefulWidget {
  const TelaHoje({
    super.key,
    required this.controleTarefa,
    this.relogio = DateTime.now,
    this.revisaoTarefas = 0,
    this.onTarefasAlteradas,
    this.onNovaTarefa,
    this.configuracoesService,
  });

  final OperacoesTarefa controleTarefa;
  final RelogioTarefa relogio;
  final int revisaoTarefas;
  final VoidCallback? onTarefasAlteradas;
  final Future<void> Function()? onNovaTarefa;
  final ConfiguracoesService? configuracoesService;

  @override
  State<TelaHoje> createState() => _TelaHojeState();
}

class _TelaHojeState extends State<TelaHoje> {
  static const _diasSemana = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  static const _meses = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  late DateTime _dataExibida;
  List<Tarefa> _tarefas = const [];
  final Set<int> _tarefasAlterandoStatus = <int>{};
  bool _carregando = true;
  String? _erroCarregamento;
  int _versaoCarregamento = 0;

  @override
  void initState() {
    super.initState();
    _dataExibida = _normalizarData(widget.relogio());
    widget.configuracoesService?.addListener(_atualizarSaudacao);
    _carregarHoje();
  }

  @override
  void didUpdateWidget(covariant TelaHoje oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuracoesService != widget.configuracoesService) {
      oldWidget.configuracoesService?.removeListener(_atualizarSaudacao);
      widget.configuracoesService?.addListener(_atualizarSaudacao);
    }
    if (oldWidget.controleTarefa != widget.controleTarefa ||
        oldWidget.relogio != widget.relogio ||
        oldWidget.revisaoTarefas != widget.revisaoTarefas) {
      _carregarHoje();
    }
  }

  @override
  void dispose() {
    _versaoCarregamento++;
    widget.configuracoesService?.removeListener(_atualizarSaudacao);
    super.dispose();
  }

  void _atualizarSaudacao() {
    if (mounted) setState(() {});
  }

  DateTime _normalizarData(DateTime data) =>
      DateTime(data.year, data.month, data.day);

  Future<void> _carregarHoje() async {
    final versao = ++_versaoCarregamento;
    final hoje = _normalizarData(widget.relogio());

    setState(() {
      _dataExibida = hoje;
      _tarefas = const [];
      _carregando = true;
      _erroCarregamento = null;
    });

    try {
      final tarefas = await widget.controleTarefa.consultarTarefasPorData(hoje);
      if (!mounted || versao != _versaoCarregamento) return;

      final ordenadas = [...tarefas]..sort(_compararTarefas);
      setState(() {
        _tarefas = ordenadas;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted || versao != _versaoCarregamento) return;
      setState(() {
        _tarefas = const [];
        _carregando = false;
        _erroCarregamento = kIsWeb
            ? 'O armazenamento de tarefas não está disponível no navegador.'
            : 'Não foi possível carregar as tarefas de hoje.';
      });
    }
  }

  int _compararTarefas(Tarefa a, Tarefa b) {
    final porHorario = _minutosDoDia(a).compareTo(_minutosDoDia(b));
    if (porHorario != 0) return porHorario;
    final porTitulo = a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
    if (porTitulo != 0) return porTitulo;
    return (a.identificador ?? 0).compareTo(b.identificador ?? 0);
  }

  int _minutosDoDia(Tarefa tarefa) {
    final horario = tarefa.horario;
    return horario == null ? 24 * 60 : horario.hora * 60 + horario.minuto;
  }

  _PeriodoDia _periodoDaTarefa(Tarefa tarefa) {
    final horario = tarefa.horario;
    if (horario == null || horario.hora >= 18) return _PeriodoDia.noite;
    if (horario.hora >= 12) return _PeriodoDia.tarde;
    return _PeriodoDia.manha;
  }

  List<Tarefa> _tarefasDoPeriodo(_PeriodoDia periodo) => _tarefas
      .where((tarefa) => _periodoDaTarefa(tarefa) == periodo)
      .toList(growable: false);

  void _registrarAlteracao() {
    final callback = widget.onTarefasAlteradas;
    if (callback != null) {
      callback();
    } else {
      unawaited(_carregarHoje());
    }
  }

  Future<void> _alternarStatus(Tarefa tarefa) async {
    final identificador = tarefa.identificador;
    if (identificador == null ||
        _tarefasAlterandoStatus.contains(identificador)) {
      return;
    }

    setState(() => _tarefasAlterandoStatus.add(identificador));
    try {
      if (tarefa.status == StatusTarefa.concluida) {
        await widget.controleTarefa.reabrirTarefa(identificador);
      } else {
        await widget.controleTarefa.concluirTarefa(identificador);
      }
      if (mounted) _registrarAlteracao();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar a situação da tarefa.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _tarefasAlterandoStatus.remove(identificador));
      }
    }
  }

  Future<void> _abrirEdicao(Tarefa tarefa) async {
    final alterou = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            TelaTarefa(controleTarefa: widget.controleTarefa, tarefa: tarefa),
      ),
    );
    if (alterou == true && mounted) _registrarAlteracao();
  }

  String _saudacao() {
    final hora = widget.relogio().hour;
    final periodo = hora < 12
        ? 'Bom dia'
        : hora < 18
        ? 'Boa tarde'
        : 'Boa noite';
    final nome = widget.configuracoesService?.configuracoes.nomeExibicao;
    return nome == null ? '$periodo!' : '$periodo, $nome!';
  }

  String _formatarData(DateTime data) {
    final diaSemana = _diasSemana[data.weekday - 1];
    final mes = _meses[data.month - 1];
    return '$diaSemana, ${data.day} de $mes de ${data.year}';
  }

  String _formatarHorario(HorarioTarefa? horario) {
    if (horario == null) return 'Sem horário';
    final hora = horario.hora.toString().padLeft(2, '0');
    final minuto = horario.minuto.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  String _formatarDuracao(Duration? duracao) {
    final minutosTotais = duracao?.inMinutes ?? 0;
    final horas = minutosTotais ~/ 60;
    final minutos = minutosTotais % 60;
    if (horas == 0) return '${minutos}min';
    if (minutos == 0) return '${horas}h';
    return '${horas}h ${minutos.toString().padLeft(2, '0')}min';
  }

  String? _formatarTempoUsado(Duration tempo) {
    if (tempo <= Duration.zero) return null;
    return '${_formatarDuracao(tempo)} usados';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: _carregarHoje,
        child: ListView(
          key: const PageStorageKey<String>('lista_hoje'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              _saudacao(),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              _formatarData(_dataExibida),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: CoresApp.textoSecundario),
            ),
            const SizedBox(height: 22),
            if (_carregando)
              const _EstadoCarregando()
            else if (_erroCarregamento != null)
              _EstadoErro(
                mensagem: _erroCarregamento!,
                onTentarNovamente: _carregarHoje,
              )
            else
              ..._construirPlanejamento(),
          ],
        ),
      ),
    );
  }

  List<Widget> _construirPlanejamento() {
    final concluidas = _tarefas
        .where((tarefa) => tarefa.status == StatusTarefa.concluida)
        .length;
    final tempoPlanejado = _tarefas.fold<Duration>(
      Duration.zero,
      (total, tarefa) => total + (tarefa.duracaoEstimada ?? Duration.zero),
    );
    final tempoRealizado = _tarefas.fold<Duration>(
      Duration.zero,
      (total, tarefa) => total + tarefa.tempoRegistrado,
    );

    final widgets = <Widget>[
      IndicadorProgresso(
        tarefasConcluidas: concluidas,
        totalTarefas: _tarefas.length,
        tempoPlanejado: _formatarDuracao(tempoPlanejado),
        tempoRealizado: _formatarDuracao(tempoRealizado),
      ),
      const SizedBox(height: 22),
    ];

    if (_tarefas.isEmpty) {
      widgets.add(const _EstadoVazio());
    } else {
      for (final periodo in _PeriodoDia.values) {
        final tarefas = _tarefasDoPeriodo(periodo);
        if (tarefas.isEmpty) continue;
        widgets
          ..add(_CabecalhoPeriodo(periodo: periodo, tarefas: tarefas))
          ..add(const SizedBox(height: 10));
        for (final tarefa in tarefas) {
          final identificador = tarefa.identificador;
          final alterando =
              identificador != null &&
              _tarefasAlterandoStatus.contains(identificador);
          widgets
            ..add(
              CardTarefa(
                key: ValueKey<String>(
                  'tarefa_hoje_${identificador ?? tarefa.titulo}',
                ),
                titulo: tarefa.titulo,
                horario: _formatarHorario(tarefa.horario),
                duracaoEstimada: _formatarDuracao(tarefa.duracaoEstimada),
                tempoUsado: _formatarTempoUsado(tarefa.tempoRegistrado),
                prioridade: tarefa.prioridade,
                status: tarefa.status,
                onTap: () => _abrirEdicao(tarefa),
                onAlternarStatus: identificador == null || alterando
                    ? null
                    : () => _alternarStatus(tarefa),
              ),
            )
            ..add(const SizedBox(height: 10));
        }
        widgets.add(const SizedBox(height: 8));
      }
    }

    final onNovaTarefa = widget.onNovaTarefa;
    if (onNovaTarefa != null) {
      widgets
        ..add(const SizedBox(height: 8))
        ..add(
          FilledButton.icon(
            key: const Key('adicionar_tarefa_hoje'),
            onPressed: onNovaTarefa,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar tarefa'),
          ),
        );
    }
    return widgets;
  }
}

class _CabecalhoPeriodo extends StatelessWidget {
  const _CabecalhoPeriodo({required this.periodo, required this.tarefas});

  final _PeriodoDia periodo;
  final List<Tarefa> tarefas;

  @override
  Widget build(BuildContext context) {
    final concluidas = tarefas
        .where((tarefa) => tarefa.status == StatusTarefa.concluida)
        .length;
    final resumo = concluidas == 0
        ? '${tarefas.length} ${tarefas.length == 1 ? 'tarefa' : 'tarefas'}'
        : '$concluidas de ${tarefas.length} concluídas';

    final (icone, titulo) = switch (periodo) {
      _PeriodoDia.manha => (Icons.wb_twilight_outlined, 'Manhã'),
      _PeriodoDia.tarde => (Icons.light_mode_outlined, 'Tarde'),
      _PeriodoDia.noite => (Icons.nightlight_round, 'Noite'),
    };

    return Row(
      children: [
        Icon(icone, color: CoresApp.principal, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titulo,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            resumo,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _EstadoCarregando extends StatelessWidget {
  const _EstadoCarregando();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 72),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text(
            'Carregando tarefas de hoje...',
            style: TextStyle(color: CoresApp.textoSecundario),
          ),
        ],
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CoresApp.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CoresApp.borda),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            color: CoresApp.principal,
            size: 40,
          ),
          SizedBox(height: 10),
          Text(
            'Nenhuma tarefa para hoje.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Aproveite o espaço livre ou planeje a próxima atividade.',
            textAlign: TextAlign.center,
            style: TextStyle(color: CoresApp.textoSecundario),
          ),
        ],
      ),
    );
  }
}

class _EstadoErro extends StatelessWidget {
  const _EstadoErro({required this.mensagem, required this.onTentarNovamente});

  final String mensagem;
  final Future<void> Function() onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CoresApp.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CoresApp.borda),
      ),
      child: Column(
        children: [
          const Icon(Icons.storage_outlined, color: CoresApp.erro, size: 40),
          const SizedBox(height: 10),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CoresApp.erro),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onTentarNovamente,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
