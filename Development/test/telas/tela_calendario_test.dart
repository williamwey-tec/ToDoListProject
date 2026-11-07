import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:to_do_list/control/control_tarefa.dart';
import 'package:to_do_list/model/tarefa.dart';
import 'package:to_do_list/telas/tela_calendario.dart';
import 'package:to_do_list/widgets/card_tarefa.dart';

class _ControleFake implements OperacoesTarefa {
  _ControleFake([List<Tarefa> tarefas = const []]) : tarefas = [...tarefas];

  final List<Tarefa> tarefas;
  int proximoIdentificador = 100;
  int consultasPorIntervalo = 0;
  DateTime? ultimoInicio;
  DateTime? ultimoFim;
  bool falharConsulta = false;
  Future<List<Tarefa>> Function(DateTime inicio, DateTime fim)? aoConsultar;

  int _indice(int identificador) =>
      tarefas.indexWhere((tarefa) => tarefa.identificador == identificador);

  @override
  Future<Tarefa> criarTarefa(Tarefa tarefa) async {
    final criada = Tarefa(
      identificador: proximoIdentificador++,
      titulo: tarefa.titulo,
      descricao: tarefa.descricao,
      data: tarefa.data,
      horario: tarefa.horario,
      duracaoEstimada: tarefa.duracaoEstimada,
      tempoRegistrado: tarefa.tempoRegistrado,
      prioridade: tarefa.prioridade,
      categoria: tarefa.categoria,
      status: tarefa.status,
    );
    tarefas.add(criada);
    return criada;
  }

  @override
  Future<Tarefa?> consultarTarefaPorId(int identificador) async {
    final indice = _indice(identificador);
    return indice < 0 ? null : tarefas[indice];
  }

  @override
  Future<List<Tarefa>> consultarTarefasPorData(DateTime data) async {
    return tarefas
        .where(
          (tarefa) =>
              tarefa.data.year == data.year &&
              tarefa.data.month == data.month &&
              tarefa.data.day == data.day,
        )
        .toList(growable: false);
  }

  @override
  Future<List<Tarefa>> consultarTarefasPorIntervalo(
    DateTime dataInicial,
    DateTime dataFinal,
  ) async {
    consultasPorIntervalo++;
    ultimoInicio = dataInicial;
    ultimoFim = dataFinal;
    if (falharConsulta) throw StateError('falha simulada');
    final consulta = aoConsultar;
    if (consulta != null) return consulta(dataInicial, dataFinal);
    return tarefas
        .where(
          (tarefa) =>
              !tarefa.data.isBefore(dataInicial) &&
              !tarefa.data.isAfter(dataFinal),
        )
        .toList(growable: false);
  }

  @override
  Future<Tarefa> editarTarefa(int identificador, Tarefa dadosEditados) async {
    final indice = _indice(identificador);
    if (indice < 0) throw TarefaNaoEncontradaException(identificador);
    final atual = tarefas[indice];
    return tarefas[indice] = Tarefa(
      identificador: identificador,
      titulo: dadosEditados.titulo,
      descricao: dadosEditados.descricao,
      data: dadosEditados.data,
      horario: dadosEditados.horario,
      duracaoEstimada: dadosEditados.duracaoEstimada,
      tempoRegistrado: atual.tempoRegistrado,
      prioridade: dadosEditados.prioridade,
      categoria: dadosEditados.categoria,
      status: atual.status,
    );
  }

  @override
  Future<Tarefa> concluirTarefa(int identificador) async {
    final indice = _indice(identificador);
    if (indice < 0) throw TarefaNaoEncontradaException(identificador);
    return tarefas[indice] = tarefas[indice].copiarComStatus(
      StatusTarefa.concluida,
    );
  }

  @override
  Future<Tarefa> reabrirTarefa(int identificador) async {
    final indice = _indice(identificador);
    if (indice < 0) throw TarefaNaoEncontradaException(identificador);
    return tarefas[indice] = tarefas[indice].copiarComStatus(
      StatusTarefa.pendente,
    );
  }

  @override
  Future<void> excluirTarefa(int identificador) async {
    tarefas.removeWhere((tarefa) => tarefa.identificador == identificador);
  }
}

Tarefa _tarefa({
  required int id,
  required String titulo,
  required DateTime data,
  StatusTarefa status = StatusTarefa.pendente,
  int estimativa = 30,
  int registrado = 0,
}) {
  return Tarefa(
    identificador: id,
    titulo: titulo,
    data: data,
    horario: HorarioTarefa(hora: 8, minuto: 0),
    duracaoEstimada: Duration(minutes: estimativa),
    tempoRegistrado: Duration(minutes: registrado),
    status: status,
  );
}

Widget _appCalendario(_ControleFake controle, {int revisao = 0, Key? key}) {
  return MaterialApp(
    home: Scaffold(
      body: TelaCalendario(
        key: key,
        controleTarefa: controle,
        relogio: () => DateTime(2026, 11, 7, 10),
        revisaoTarefas: revisao,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'abre em hoje, consulta o mês uma vez e persiste conclusão e reabertura',
    (tester) async {
      final controle = _ControleFake([
        _tarefa(
          id: 1,
          titulo: 'Planejar entrega',
          data: DateTime(2026, 11, 7),
          estimativa: 30,
          registrado: 12,
        ),
        _tarefa(
          id: 2,
          titulo: 'Revisar notas',
          data: DateTime(2026, 11, 7),
          status: StatusTarefa.concluida,
          estimativa: 45,
          registrado: 20,
        ),
        _tarefa(
          id: 3,
          titulo: 'Tarefa de outro dia',
          data: DateTime(2026, 11, 9),
        ),
      ]);

      await tester.pumpWidget(_appCalendario(controle));
      await tester.pumpAndSettle();

      expect(find.text('Sábado, 7 de novembro'), findsOneWidget);
      expect(controle.consultasPorIntervalo, 1);
      expect(controle.ultimoInicio, DateTime(2026, 11, 1));
      expect(controle.ultimoFim, DateTime(2026, 11, 30));
      expect(find.byKey(const ValueKey('marcador_2026-11-7')), findsOneWidget);
      expect(find.byKey(const ValueKey('marcador_2026-11-9')), findsOneWidget);
      expect(find.text('08:00 · 30 min'), findsOneWidget);
      expect(find.text('12 min usados'), findsOneWidget);
      expect(find.text('20 min realizados'), findsOneWidget);

      final cardPendente = find.ancestor(
        of: find.text('Planejar entrega'),
        matching: find.byType(CardTarefa),
      );
      final botaoConcluir = find.descendant(
        of: cardPendente,
        matching: find.byType(IconButton),
      );
      await tester.ensureVisible(botaoConcluir);
      await tester.tap(botaoConcluir);
      await tester.pumpAndSettle();
      expect(
        (await controle.consultarTarefaPorId(1))?.status,
        StatusTarefa.concluida,
      );
      expect(find.text('2 concluídas'), findsOneWidget);

      final concluida = find.ancestor(
        of: find.text('Planejar entrega'),
        matching: find.byType(InkWell),
      );
      final botaoReabrir = find.descendant(
        of: concluida.first,
        matching: find.byType(IconButton),
      );
      await tester.ensureVisible(botaoReabrir);
      await tester.tap(botaoReabrir);
      await tester.pumpAndSettle();
      expect(
        (await controle.consultarTarefaPorId(1))?.status,
        StatusTarefa.pendente,
      );

      await tester.ensureVisible(find.text('Planejar entrega'));
      await tester.tap(find.text('Planejar entrega'));
      await tester.pumpAndSettle();
      expect(find.text('Editar tarefa'), findsOneWidget);
    },
  );

  testWidgets('revisão externa reflete edição de data e exclusão', (
    tester,
  ) async {
    const chave = ValueKey('calendario');
    final controle = _ControleFake([
      _tarefa(id: 1, titulo: 'Antes da edição', data: DateTime(2026, 11, 7)),
    ]);

    await tester.pumpWidget(_appCalendario(controle, key: chave));
    await tester.pumpAndSettle();
    expect(find.text('Antes da edição'), findsOneWidget);

    controle.tarefas[0] = _tarefa(
      id: 1,
      titulo: 'Depois da edição',
      data: DateTime(2026, 11, 9),
    );
    await tester.pumpWidget(_appCalendario(controle, revisao: 1, key: chave));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('marcador_2026-11-7')), findsNothing);
    expect(find.byKey(const ValueKey('marcador_2026-11-9')), findsOneWidget);

    await tester.tap(find.text('9'));
    await tester.pumpAndSettle();
    expect(find.text('Depois da edição'), findsOneWidget);

    controle.tarefas.clear();
    await tester.pumpWidget(_appCalendario(controle, revisao: 2, key: chave));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('marcador_2026-11-9')), findsNothing);
    expect(
      find.text('Nenhuma tarefa planejada para este dia.'),
      findsOneWidget,
    );
  });

  testWidgets('ignora resposta antiga após mudança rápida de mês', (
    tester,
  ) async {
    final novembro = Completer<List<Tarefa>>();
    final dezembro = Completer<List<Tarefa>>();
    final controle = _ControleFake()
      ..aoConsultar = (inicio, _) =>
          inicio.month == 11 ? novembro.future : dezembro.future;

    await tester.pumpWidget(_appCalendario(controle));
    await tester.pump();

    final calendario = tester.widget<TableCalendar<Tarefa>>(
      find.byType(TableCalendar<Tarefa>),
    );
    calendario.onPageChanged!(DateTime(2026, 12, 1));
    await tester.pump();

    dezembro.complete([
      _tarefa(
        id: 2,
        titulo: 'Resposta mais recente',
        data: DateTime(2026, 12, 7),
      ),
    ]);
    await tester.pump();
    novembro.complete([
      _tarefa(id: 1, titulo: 'Resposta obsoleta', data: DateTime(2026, 11, 7)),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Segunda, 7 de dezembro'), findsOneWidget);
    expect(find.text('Resposta mais recente'), findsOneWidget);
    expect(find.text('Resposta obsoleta'), findsNothing);
  });

  testWidgets('exibe erro com retry e depois o estado vazio', (tester) async {
    final controle = _ControleFake()..falharConsulta = true;

    await tester.pumpWidget(_appCalendario(controle));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar as tarefas deste mês.'),
      findsWidgets,
    );

    controle.falharConsulta = false;
    await tester.ensureVisible(find.text('Tentar novamente'));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nenhuma tarefa planejada para este dia.'),
      findsOneWidget,
    );
  });
}
