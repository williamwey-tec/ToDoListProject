import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../tema/cores.dart';
import '../widgets/card_tarefa.dart';
import 'tela_tarefa.dart';

/// Modelo auxiliar local para representar uma tarefa exibida na tela de Calendário.
class _TarefaCalendario {
  final String titulo;
  final String horario;
  final int duracaoMinutos;
  final int? minutosUsados;
  final PrioridadeTarefa prioridade;
  StatusTarefa status;

  _TarefaCalendario({
    required this.titulo,
    required this.horario,
    required this.duracaoMinutos,
    this.minutosUsados,
    required this.prioridade,
    required this.status,
  });
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
  late final Map<DateTime, List<_TarefaCalendario>> _tarefasPorDia;

  @override
  void initState() {
    super.initState();
    _tarefasPorDia = _criarDadosIniciais();
  }

  DateTime _normalizarData(DateTime data) =>
      DateTime(data.year, data.month, data.day);

  Map<DateTime, List<_TarefaCalendario>> _criarDadosIniciais() {
    final mapa = <DateTime, List<_TarefaCalendario>>{};

    // Tarefas detalhadas do dia 8 de outubro de 2026 (conforme protótipo)
    mapa[DateTime(2026, 10, 8)] = [
      _TarefaCalendario(
        titulo: 'Organizar e-mails',
        horario: '08:00',
        duracaoMinutos: 20,
        minutosUsados: 15,
        prioridade: PrioridadeTarefa.baixa,
        status: StatusTarefa.concluida,
      ),
      _TarefaCalendario(
        titulo: 'Planejar o dia',
        horario: '09:00',
        duracaoMinutos: 15,
        minutosUsados: 15,
        prioridade: PrioridadeTarefa.baixa,
        status: StatusTarefa.concluida,
      ),
      _TarefaCalendario(
        titulo: 'Ler referências',
        horario: '10:00',
        duracaoMinutos: 30,
        minutosUsados: 25,
        prioridade: PrioridadeTarefa.media,
        status: StatusTarefa.concluida,
      ),
      _TarefaCalendario(
        titulo: 'Enviar relatório',
        horario: '13:00',
        duracaoMinutos: 30,
        prioridade: PrioridadeTarefa.alta,
        status: StatusTarefa.atrasada,
      ),
      _TarefaCalendario(
        titulo: 'Revisar apresentação',
        horario: '14:00',
        duracaoMinutos: 45,
        minutosUsados: 20,
        prioridade: PrioridadeTarefa.alta,
        status: StatusTarefa.pausada,
      ),
      _TarefaCalendario(
        titulo: 'Consulta médica',
        horario: '16:00',
        duracaoMinutos: 45,
        prioridade: PrioridadeTarefa.media,
        status: StatusTarefa.pendente,
      ),
      _TarefaCalendario(
        titulo: 'Estudar Flutter',
        horario: '19:00',
        duracaoMinutos: 60,
        prioridade: PrioridadeTarefa.baixa,
        status: StatusTarefa.pendente,
      ),
    ];

    // Outros dias do mês marcados com tarefas conforme os indicadores do protótipo
    const diasComTarefas = [5, 6, 7, 12, 14, 16, 19, 21, 23, 26, 28];
    for (final dia in diasComTarefas) {
      mapa[DateTime(2026, 10, dia)] = [
        _TarefaCalendario(
          titulo: 'Planejamento de estudos',
          horario: '09:00',
          duracaoMinutos: 45,
          prioridade: PrioridadeTarefa.media,
          status: StatusTarefa.pendente,
        ),
        _TarefaCalendario(
          titulo: 'Revisão da Sprint FlowTask',
          horario: '14:00',
          duracaoMinutos: 30,
          minutosUsados: 30,
          prioridade: PrioridadeTarefa.alta,
          status: StatusTarefa.concluida,
        ),
      ];
    }

    return mapa;
  }

  List<_TarefaCalendario> _obterTarefasDoDia(DateTime dia) {
    return _tarefasPorDia[_normalizarData(dia)] ?? [];
  }

  void _alternarStatusTarefa(_TarefaCalendario tarefa) {
    setState(() {
      if (tarefa.status == StatusTarefa.concluida) {
        tarefa.status = StatusTarefa.pendente;
      } else {
        tarefa.status = StatusTarefa.concluida;
      }
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

  String _construirResumoContagem(List<_TarefaCalendario> tarefas) {
    final concluidas =
        tarefas.where((t) => t.status == StatusTarefa.concluida).length;
    final pendentes =
        tarefas.where((t) => t.status == StatusTarefa.pendente).length;
    final pausadas =
        tarefas.where((t) => t.status == StatusTarefa.pausada).length;
    final atrasadas =
        tarefas.where((t) => t.status == StatusTarefa.atrasada).length;

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
      (soma, t) => soma + (t.minutosUsados ?? t.duracaoMinutos),
    );

    return Scaffold(
      backgroundColor: CoresApp.fundo,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da tela de Calendário
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendário',
                      style: TextStyle(
                        color: CoresApp.texto,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Um dia de cada vez',
                      style: TextStyle(
                        color: CoresApp.textoSecundario,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TelaTarefa(),
                      ),
                    );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: CoresApp.principalSuave,
                    fixedSize: const Size(46, 46),
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(
                    Icons.add_rounded,
                    color: CoresApp.principal,
                    size: 26,
                  ),
                  tooltip: 'Nova tarefa',
                ),
              ],
            ),
            const SizedBox(height: 20),

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
                  TableCalendar<_TarefaCalendario>(
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
                    horario: tarefa.horario,
                    duracaoEstimada: '${tarefa.duracaoMinutos} min',
                    tempoUsado: tarefa.minutosUsados != null
                        ? '${tarefa.minutosUsados} min usados'
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
  final _TarefaCalendario tarefa;
  final VoidCallback onAlternarStatus;

  const _CardTarefaConcluidaCompacto({
    required this.tarefa,
    required this.onAlternarStatus,
  });

  @override
  Widget build(BuildContext context) {
    final int minutosExibidos = tarefa.minutosUsados ?? tarefa.duracaoMinutos;

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
                  border: Border.all(
                    color: CoresApp.concluida,
                    width: 1.8,
                  ),
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
                      '${tarefa.horario} · Concluída',
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
