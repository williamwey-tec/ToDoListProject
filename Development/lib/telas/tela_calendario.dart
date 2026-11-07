import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../control/control_tarefa.dart';
import '../model/tarefa.dart';
import '../tema/cores.dart';
import '../widgets/card_tarefa.dart';
import 'tela_tarefa.dart';

String _formatarHorario(HorarioTarefa? horario) {
  if (horario == null) return 'Sem horário';

  final hora = horario.hora.toString().padLeft(2, '0');
  final minuto = horario.minuto.toString().padLeft(2, '0');
  return '$hora:$minuto';
}

String _formatarDuracao(Duration? duracao) {
  return duracao == null ? 'Sem estimativa' : '${duracao.inMinutes} min';
}

/// Calendário interativo e listagem de tarefas da data selecionada
/// seguindo fielmente o protótipo em `Design/Calendário.jpg`.
class TelaCalendario extends StatefulWidget {
  const TelaCalendario({
    super.key,
    required this.controleTarefa,
    this.onDataSelecionada,
    this.onTarefasAlteradas,
    this.relogio = DateTime.now,
    this.revisaoTarefas = 0,
  });

  final OperacoesTarefa controleTarefa;
  final ValueChanged<DateTime>? onDataSelecionada;
  final VoidCallback? onTarefasAlteradas;
  final RelogioTarefa relogio;
  final int revisaoTarefas;

  @override
  State<TelaCalendario> createState() => _TelaCalendarioState();
}

class _TelaCalendarioState extends State<TelaCalendario> {
  static const List<String> _nomesMeses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  static const List<String> _nomesDiasSemana = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  static const List<String> _iniciaisDiasSemana = [
    'S',
    'T',
    'Q',
    'Q',
    'S',
    'S',
    'D',
  ];

  late DateTime _mesFocado;
  late DateTime _diaSelecionado;
  Map<DateTime, List<Tarefa>> _tarefasPorDia = const {};
  final Set<int> _tarefasAlterandoStatus = <int>{};
  bool _carregando = true;
  String? _erroCarregamento;
  int _versaoCarregamento = 0;

  @override
  void initState() {
    super.initState();
    final hoje = _normalizarData(widget.relogio());
    _mesFocado = hoje;
    _diaSelecionado = hoje;
    _carregarMes(_mesFocado);
  }

  @override
  void didUpdateWidget(covariant TelaCalendario oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controleTarefa != widget.controleTarefa ||
        oldWidget.revisaoTarefas != widget.revisaoTarefas) {
      _carregarMes(_mesFocado);
    }
  }

  @override
  void dispose() {
    _versaoCarregamento++;
    super.dispose();
  }

  DateTime _normalizarData(DateTime data) =>
      DateTime(data.year, data.month, data.day);

  Future<void> _carregarMes(DateTime mes) async {
    final versao = ++_versaoCarregamento;
    final inicio = DateTime(mes.year, mes.month);
    final fim = DateTime(mes.year, mes.month + 1, 0);

    setState(() {
      _tarefasPorDia = const {};
      _carregando = true;
      _erroCarregamento = null;
    });

    try {
      final tarefas = await widget.controleTarefa.consultarTarefasPorIntervalo(
        inicio,
        fim,
      );
      if (!mounted || versao != _versaoCarregamento) return;

      final porDia = <DateTime, List<Tarefa>>{};
      for (final tarefa in tarefas) {
        porDia.putIfAbsent(_normalizarData(tarefa.data), () => []).add(tarefa);
      }
      setState(() {
        _tarefasPorDia = porDia;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted || versao != _versaoCarregamento) return;
      setState(() {
        _tarefasPorDia = const {};
        _carregando = false;
        _erroCarregamento = kIsWeb
            ? 'O armazenamento de tarefas não está disponível no navegador.'
            : 'Não foi possível carregar as tarefas deste mês.';
      });
    }
  }

  List<Tarefa> _obterTarefasDoDia(DateTime dia) {
    return _tarefasPorDia[_normalizarData(dia)] ?? [];
  }

  Future<void> _registrarAlteracao() async {
    final callback = widget.onTarefasAlteradas;
    if (callback != null) {
      callback();
    } else {
      await _carregarMes(_mesFocado);
    }
  }

  Future<void> _alternarStatusTarefa(Tarefa tarefa) async {
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
      if (mounted) await _registrarAlteracao();
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
    if (alterou == true && mounted) await _registrarAlteracao();
  }

  String _formatarMesAno(DateTime data) {
    final mes = _nomesMeses[data.month - 1];
    return '$mes de ${data.year}';
  }

  String _formatarDiaSelecionado(DateTime data) {
    final diaSemana = _nomesDiasSemana[data.weekday - 1];
    final mes = _nomesMeses[data.month - 1].toLowerCase();
    return '$diaSemana, ${data.day} de $mes';
  }

  String _formatarHoje() {
    final hoje = _normalizarData(widget.relogio());
    return 'hoje, ${hoje.day} de ${_nomesMeses[hoje.month - 1].toLowerCase()}';
  }

  String _construirResumoContagem(List<Tarefa> tarefas) {
    final concluidas = tarefas
        .where((t) => t.status == StatusTarefa.concluida)
        .length;
    final pendentes = tarefas
        .where((t) => t.status == StatusTarefa.pendente)
        .length;
    final pausadas = tarefas
        .where((t) => t.status == StatusTarefa.pausada)
        .length;
    final atrasadas = tarefas
        .where((t) => t.status == StatusTarefa.atrasada)
        .length;

    final partes = <String>[];
    if (concluidas > 0) {
      partes.add('$concluidas ${concluidas == 1 ? 'concluída' : 'concluídas'}');
    }
    if (pendentes > 0) {
      partes.add('$pendentes ${pendentes == 1 ? 'pendente' : 'pendentes'}');
    }
    if (pausadas > 0) {
      partes.add('$pausadas ${pausadas == 1 ? 'pausada' : 'pausadas'}');
    }
    if (atrasadas > 0) {
      partes.add('$atrasadas ${atrasadas == 1 ? 'atrasada' : 'atrasadas'}');
    }

    return partes.isEmpty ? 'Nenhuma tarefa registrada' : partes.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final tarefasDoDia = _obterTarefasDoDia(_diaSelecionado);
    final tarefasAtivas = tarefasDoDia
        .where((t) => t.status != StatusTarefa.concluida)
        .toList();
    final tarefasConcluidas = tarefasDoDia
        .where((t) => t.status == StatusTarefa.concluida)
        .toList();

    final int totalMinutosRealizados = tarefasConcluidas.fold(
      0,
      (soma, t) => soma + t.tempoRegistrado.inMinutes,
    );

    return Scaffold(
      backgroundColor: CoresApp.fundo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card do Calendário Mensal
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              decoration: BoxDecoration(
                color: CoresApp.superficie,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: CoresApp.borda, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TableCalendar<Tarefa>(
                    firstDay: DateTime(2020, 1, 1),
                    lastDay: DateTime(2030, 12, 31),
                    focusedDay: _mesFocado,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    selectedDayPredicate: (day) =>
                        isSameDay(_diaSelecionado, day),
                    eventLoader: _obterTarefasDoDia,
                    availableGestures: AvailableGestures.horizontalSwipe,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextFormatter: (date, _) => _formatarMesAno(date),
                      titleTextStyle: const TextStyle(
                        color: CoresApp.texto,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      leftChevronIcon: const Icon(
                        Icons.chevron_left_rounded,
                        color: CoresApp.texto,
                        size: 26,
                      ),
                      rightChevronIcon: const Icon(
                        Icons.chevron_right_rounded,
                        color: CoresApp.texto,
                        size: 26,
                      ),
                      headerPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    daysOfWeekHeight: 32,
                    rowHeight: 50,
                    onDaySelected: (selectedDay, focusedDay) {
                      final mudouMes =
                          selectedDay.year != _mesFocado.year ||
                          selectedDay.month != _mesFocado.month;
                      final novoFoco = mudouMes ? selectedDay : focusedDay;
                      setState(() {
                        _diaSelecionado = _normalizarData(selectedDay);
                        _mesFocado = novoFoco;
                      });
                      widget.onDataSelecionada?.call(_diaSelecionado);
                      if (mudouMes) _carregarMes(novoFoco);
                    },
                    onPageChanged: (focusedDay) {
                      final ultimoDia = DateTime(
                        focusedDay.year,
                        focusedDay.month + 1,
                        0,
                      ).day;
                      final diaPreservado = _diaSelecionado.day > ultimoDia
                          ? ultimoDia
                          : _diaSelecionado.day;
                      setState(() {
                        _mesFocado = focusedDay;
                        _diaSelecionado = DateTime(
                          focusedDay.year,
                          focusedDay.month,
                          diaPreservado,
                        );
                      });
                      widget.onDataSelecionada?.call(_diaSelecionado);
                      _carregarMes(focusedDay);
                    },
                    calendarBuilders: CalendarBuilders(
                      dowBuilder: (context, day) {
                        final inicial = _iniciaisDiasSemana[day.weekday - 1];
                        return Center(
                          child: Text(
                            inicial,
                            style: const TextStyle(
                              color: CoresApp.textoSecundario,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                      defaultBuilder: (context, day, focusedDay) {
                        return _construirCelulaDia(
                          dia: day,
                          selecionado: false,
                          possuiTarefas: _obterTarefasDoDia(day).isNotEmpty,
                        );
                      },
                      todayBuilder: (context, day, focusedDay) {
                        return _construirCelulaDia(
                          dia: day,
                          selecionado: isSameDay(day, _diaSelecionado),
                          possuiTarefas: _obterTarefasDoDia(day).isNotEmpty,
                        );
                      },
                      selectedBuilder: (context, day, focusedDay) {
                        return _construirCelulaDia(
                          dia: day,
                          selecionado: true,
                          possuiTarefas: _obterTarefasDoDia(day).isNotEmpty,
                        );
                      },
                      markerBuilder: (context, day, events) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Legenda inferior do calendário
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: CoresApp.principal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dias com tarefas · ${_formatarHoje()}',
                            style: const TextStyle(
                              color: CoresApp.textoSecundario,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cabeçalho da data selecionada
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatarDiaSelecionado(_diaSelecionado),
                  style: const TextStyle(
                    color: CoresApp.texto,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _carregando
                      ? 'Carregando...'
                      : _erroCarregamento != null
                      ? 'Indisponível'
                      : '${tarefasDoDia.length} ${tarefasDoDia.length == 1 ? 'tarefa' : 'tarefas'}',
                  style: const TextStyle(
                    color: CoresApp.textoSecundario,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _carregando
                  ? 'Consultando as tarefas do mês'
                  : _erroCarregamento ?? _construirResumoContagem(tarefasDoDia),
              style: const TextStyle(
                color: CoresApp.textoSecundario,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Lista de Tarefas Pendentes / Pausadas / Atrasadas do dia
            if (_carregando)
              _construirEstadoCarregamento()
            else if (_erroCarregamento != null)
              _construirEstadoErro()
            else if (tarefasAtivas.isEmpty && tarefasConcluidas.isEmpty)
              Container(
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
                      Icons.event_available_rounded,
                      color: CoresApp.textoSecundario,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Nenhuma tarefa planejada para este dia.',
                      style: TextStyle(
                        color: CoresApp.textoSecundario,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...tarefasAtivas.map(
                (tarefa) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardTarefa(
                    titulo: tarefa.titulo,
                    horario: _formatarHorario(tarefa.horario),
                    duracaoEstimada: _formatarDuracao(tarefa.duracaoEstimada),
                    tempoUsado: tarefa.tempoRegistrado > Duration.zero
                        ? '${tarefa.tempoRegistrado.inMinutes} min usados'
                        : null,
                    prioridade: tarefa.prioridade,
                    status: tarefa.status,
                    onTap: () => _abrirEdicao(tarefa),
                    onAlternarStatus:
                        _tarefasAlterandoStatus.contains(tarefa.identificador)
                        ? null
                        : () => _alternarStatusTarefa(tarefa),
                  ),
                ),
              ),

            // Seção de Tarefas Concluídas
            if (!_carregando &&
                _erroCarregamento == null &&
                tarefasConcluidas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Concluídas',
                    style: TextStyle(
                      color: CoresApp.texto,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$totalMinutosRealizados min realizados',
                    style: const TextStyle(
                      color: CoresApp.textoSecundario,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...tarefasConcluidas.map(
                (tarefa) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CardTarefaConcluidaCompacto(
                    tarefa: tarefa,
                    onTap: () => _abrirEdicao(tarefa),
                    onAlternarStatus:
                        _tarefasAlterandoStatus.contains(tarefa.identificador)
                        ? null
                        : () => _alternarStatusTarefa(tarefa),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _construirEstadoCarregamento() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: CoresApp.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CoresApp.borda),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'Carregando tarefas...',
            style: TextStyle(color: CoresApp.textoSecundario),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoErro() {
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
          const Icon(Icons.storage_outlined, color: CoresApp.erro, size: 36),
          const SizedBox(height: 8),
          Text(
            _erroCarregamento!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CoresApp.erro),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _carregarMes(_mesFocado),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _construirCelulaDia({
    required DateTime dia,
    required bool selecionado,
    required bool possuiTarefas,
  }) {
    return Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selecionado ? CoresApp.principal : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${dia.day}',
              style: TextStyle(
                color: selecionado ? CoresApp.sobrePrincipal : CoresApp.texto,
                fontSize: 15,
                fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            if (possuiTarefas)
              Container(
                key: ValueKey<String>(
                  'marcador_${dia.year}-${dia.month}-${dia.day}',
                ),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: selecionado
                      ? CoresApp.sobrePrincipal
                      : CoresApp.principal,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}

/// Card compacto verde para exibição das tarefas concluídas na tela de Calendário
/// conforme o protótipo `Design/Calendário.jpg`.
class _CardTarefaConcluidaCompacto extends StatelessWidget {
  final Tarefa tarefa;
  final VoidCallback onTap;
  final VoidCallback? onAlternarStatus;

  const _CardTarefaConcluidaCompacto({
    required this.tarefa,
    required this.onTap,
    required this.onAlternarStatus,
  });

  @override
  Widget build(BuildContext context) {
    final int minutosExibidos = tarefa.tempoRegistrado.inMinutes;

    return Material(
      color: CoresApp.concluidaFundo,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              IconButton(
                onPressed: onAlternarStatus,
                tooltip: 'Marcar tarefa como pendente',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: CoresApp.concluida, width: 1.8),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: CoresApp.concluida,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tarefa.titulo,
                      style: const TextStyle(
                        color: CoresApp.texto,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatarHorario(tarefa.horario)} · Concluída',
                      style: const TextStyle(
                        color: CoresApp.concluida,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$minutosExibidos min',
                style: const TextStyle(
                  color: CoresApp.concluida,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
