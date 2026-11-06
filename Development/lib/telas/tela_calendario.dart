import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../model/tarefa.dart';
import '../tema/cores.dart';
import '../widgets/card_tarefa.dart';

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
  const TelaCalendario({super.key});

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

  DateTime _mesFocado = DateTime(2026, 10, 8);
  DateTime _diaSelecionado = DateTime(2026, 10, 8);

  // Mapa de tarefas por data (normalizada ano/mês/dia) para demonstração e interação
  late final Map<DateTime, List<Tarefa>> _tarefasPorDia;

  @override
  void initState() {
    super.initState();
    _tarefasPorDia = _criarDadosIniciais();
  }

  DateTime _normalizarData(DateTime data) =>
      DateTime(data.year, data.month, data.day);

  Map<DateTime, List<Tarefa>> _criarDadosIniciais() {
    final mapa = <DateTime, List<Tarefa>>{};

    // Tarefas detalhadas do dia 8 de outubro de 2026 (conforme protótipo)
    mapa[DateTime(2026, 10, 8)] = [
      Tarefa(
        titulo: 'Organizar e-mails',
        data: DateTime(2026, 10, 8),
        horario: HorarioTarefa(hora: 8, minuto: 0),
        duracaoEstimada: const Duration(minutes: 20),
        tempoRegistrado: const Duration(minutes: 15),
        prioridade: PrioridadeTarefa.baixa,
        status: StatusTarefa.concluida,
      ),
      Tarefa(
        titulo: 'Planejar o dia',
        data: DateTime(2026, 10, 8),
        horario: HorarioTarefa(hora: 9, minuto: 0),
        duracaoEstimada: const Duration(minutes: 15),
        tempoRegistrado: const Duration(minutes: 15),
        prioridade: PrioridadeTarefa.baixa,
        status: StatusTarefa.concluida,
      ),
      Tarefa(
        titulo: 'Ler referências',
        data: DateTime(2026, 10, 8),
        horario: HorarioTarefa(hora: 10, minuto: 0),
        duracaoEstimada: const Duration(minutes: 30),
        tempoRegistrado: const Duration(minutes: 25),
        prioridade: PrioridadeTarefa.media,
        status: StatusTarefa.concluida,
      ),
      Tarefa(
        titulo: 'Enviar relatório',
        data: DateTime(2026, 10, 8),
        horario: HorarioTarefa(hora: 13, minuto: 0),
        duracaoEstimada: const Duration(minutes: 30),
        prioridade: PrioridadeTarefa.alta,
        status: StatusTarefa.atrasada,
      ),
      Tarefa(
        titulo: 'Revisar apresentação',
        data: DateTime(2026, 10, 8),
        horario: HorarioTarefa(hora: 14, minuto: 0),
        duracaoEstimada: const Duration(minutes: 45),
        tempoRegistrado: const Duration(minutes: 20),
        prioridade: PrioridadeTarefa.alta,
        status: StatusTarefa.pausada,
      ),
      Tarefa(
        titulo: 'Consulta médica',
        data: DateTime(2026, 10, 8),
        horario: HorarioTarefa(hora: 16, minuto: 0),
        duracaoEstimada: const Duration(minutes: 45),
        prioridade: PrioridadeTarefa.media,
        status: StatusTarefa.pendente,
      ),
      Tarefa(
        titulo: 'Estudar Flutter',
        data: DateTime(2026, 10, 8),
        horario: HorarioTarefa(hora: 19, minuto: 0),
        duracaoEstimada: const Duration(minutes: 60),
        prioridade: PrioridadeTarefa.baixa,
        status: StatusTarefa.pendente,
      ),
    ];

    // Outros dias do mês marcados com tarefas conforme os indicadores do protótipo
    const diasComTarefas = [5, 6, 7, 12, 14, 16, 19, 21, 23, 26, 28];
    for (final dia in diasComTarefas) {
      mapa[DateTime(2026, 10, dia)] = [
        Tarefa(
          titulo: 'Planejamento de estudos',
          data: DateTime(2026, 10, dia),
          horario: HorarioTarefa(hora: 9, minuto: 0),
          duracaoEstimada: const Duration(minutes: 45),
          prioridade: PrioridadeTarefa.media,
          status: StatusTarefa.pendente,
        ),
        Tarefa(
          titulo: 'Revisão da Sprint FlowTask',
          data: DateTime(2026, 10, dia),
          horario: HorarioTarefa(hora: 14, minuto: 0),
          duracaoEstimada: const Duration(minutes: 30),
          tempoRegistrado: const Duration(minutes: 30),
          prioridade: PrioridadeTarefa.alta,
          status: StatusTarefa.concluida,
        ),
      ];
    }

    return mapa;
  }

  List<Tarefa> _obterTarefasDoDia(DateTime dia) {
    return _tarefasPorDia[_normalizarData(dia)] ?? [];
  }

  void _alternarStatusTarefa(Tarefa tarefa) {
    setState(() {
      final data = _normalizarData(tarefa.data);
      final tarefas = _tarefasPorDia[data];
      if (tarefas == null) return;

      final indice = tarefas.indexOf(tarefa);
      if (indice < 0) return;

      final novoStatus = tarefa.status == StatusTarefa.concluida
          ? StatusTarefa.pendente
          : StatusTarefa.concluida;
      tarefas[indice] = tarefa.copiarComStatus(novoStatus);
    });
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
                      setState(() {
                        _diaSelecionado = selectedDay;
                        _mesFocado = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _mesFocado = focusedDay;
                      });
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
                        const Text(
                          'Dias com tarefas · hoje, 8 de outubro',
                          style: TextStyle(
                            color: CoresApp.textoSecundario,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
                  '${tarefasDoDia.length} ${tarefasDoDia.length == 1 ? 'tarefa' : 'tarefas'}',
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
              _construirResumoContagem(tarefasDoDia),
              style: const TextStyle(
                color: CoresApp.textoSecundario,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Lista de Tarefas Pendentes / Pausadas / Atrasadas do dia
            if (tarefasAtivas.isEmpty && tarefasConcluidas.isEmpty)
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
                    onAlternarStatus: () => _alternarStatusTarefa(tarefa),
                  ),
                ),
              ),

            // Seção de Tarefas Concluídas
            if (tarefasConcluidas.isNotEmpty) ...[
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
                    onAlternarStatus: () => _alternarStatusTarefa(tarefa),
                  ),
                ),
              ),
            ],
          ],
        ),
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
  final VoidCallback onAlternarStatus;

  const _CardTarefaConcluidaCompacto({
    required this.tarefa,
    required this.onAlternarStatus,
  });

  @override
  Widget build(BuildContext context) {
    final int minutosExibidos = tarefa.tempoRegistrado.inMinutes;

    return Material(
      color: CoresApp.concluidaFundo,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onAlternarStatus,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
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
              const SizedBox(width: 14),
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
