import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_list/control/control_tarefa.dart';
import 'package:to_do_list/model/tarefa.dart';
import 'package:to_do_list/telas/tela_hoje.dart';
import 'package:to_do_list/tema/tema_app.dart';
import 'package:to_do_list/widgets/card_tarefa.dart';

class _ControleFake implements OperacoesTarefa {
  _ControleFake([List<Tarefa> tarefas = const []]) : tarefas = [...tarefas];

  final List<Tarefa> tarefas;
  int consultasPorData = 0;
  bool falharConsulta = false;
  Future<List<Tarefa>> Function(DateTime data)? aoConsultar;

  int _indice(int identificador) =>
      tarefas.indexWhere((tarefa) => tarefa.identificador == identificador);

  @override
  Future<Tarefa> criarTarefa(Tarefa tarefa) async {
    final criada = Tarefa(
      identificador: tarefas.length + 100,
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
    consultasPorData++;
    if (falharConsulta) throw StateError('falha simulada');
    final consulta = aoConsultar;
    if (consulta != null) return consulta(data);
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

DateTime _agora() => DateTime(2026, 11, 7, 14, 20);

Tarefa _tarefa({
  required int id,
  required String titulo,
  HorarioTarefa? horario,
  Duration estimativa = const Duration(minutes: 30),
  Duration registrado = Duration.zero,
  StatusTarefa status = StatusTarefa.pendente,
}) {
  return Tarefa(
    identificador: id,
    titulo: titulo,
    data: DateTime(2026, 11, 7),
    horario: horario,
    duracaoEstimada: estimativa,
    tempoRegistrado: registrado,
    status: status,
  );
}

Widget _app(
  _ControleFake controle, {
  Key? key,
  int revisao = 0,
  Future<void> Function()? onNovaTarefa,
}) {
  return MaterialApp(
    theme: TemaApp.claro,
    home: Scaffold(
      body: TelaHoje(
        key: key,
        controleTarefa: controle,
        relogio: _agora,
        revisaoTarefas: revisao,
        onNovaTarefa: onNovaTarefa,
      ),
    ),
  );
}

void main() {
  testWidgets('agrupa, ordena e calcula progresso e tempos reais', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controle = _ControleFake([
      _tarefa(
        id: 4,
        titulo: 'Pendência sem horário',
        estimativa: const Duration(minutes: 25),
        registrado: const Duration(minutes: 5),
        status: StatusTarefa.concluida,
      ),
      _tarefa(
        id: 3,
        titulo: 'Atividade noturna',
        horario: HorarioTarefa(hora: 18, minuto: 0),
        estimativa: const Duration(minutes: 60),
      ),
      _tarefa(
        id: 2,
        titulo: 'Atividade da tarde',
        horario: HorarioTarefa(hora: 12, minuto: 0),
        estimativa: const Duration(minutes: 45),
        registrado: const Duration(minutes: 20),
      ),
      _tarefa(
        id: 1,
        titulo: 'Atividade da manhã',
        horario: HorarioTarefa(hora: 8, minuto: 0),
        estimativa: const Duration(minutes: 30),
        registrado: const Duration(minutes: 15),
        status: StatusTarefa.concluida,
      ),
    ]);

    await tester.pumpWidget(_app(controle));
    await tester.pumpAndSettle();

    expect(find.text('Boa tarde!'), findsOneWidget);
    expect(find.text('Sábado, 7 de novembro de 2026'), findsOneWidget);
    expect(find.text('2 de 4 tarefas concluídas'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('2h 40min'), findsOneWidget);
    expect(find.text('40min'), findsOneWidget);
    expect(find.text('Manhã'), findsOneWidget);
    expect(find.text('Tarde'), findsOneWidget);
    expect(find.text('Noite'), findsOneWidget);
    expect(find.text('15min usados'), findsOneWidget);
    expect(find.text('20min usados'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Atividade noturna')).dy,
      lessThan(tester.getTopLeft(find.text('Pendência sem horário')).dy),
    );
  });

  testWidgets('conclui e reabre atualizando o progresso', (tester) async {
    final controle = _ControleFake([
      _tarefa(
        id: 1,
        titulo: 'Alternar situação',
        horario: HorarioTarefa(hora: 9, minuto: 0),
      ),
    ]);

    await tester.pumpWidget(_app(controle));
    await tester.pumpAndSettle();

    Finder botaoStatus() => find.descendant(
      of: find.ancestor(
        of: find.text('Alternar situação'),
        matching: find.byType(CardTarefa),
      ),
      matching: find.byType(IconButton),
    );

    await tester.tap(botaoStatus());
    await tester.pumpAndSettle();
    expect(controle.tarefas.single.status, StatusTarefa.concluida);
    expect(find.text('1 de 1 tarefas concluídas'), findsOneWidget);

    await tester.tap(botaoStatus());
    await tester.pumpAndSettle();
    expect(controle.tarefas.single.status, StatusTarefa.pendente);
    expect(find.text('0 de 1 tarefas concluídas'), findsOneWidget);
  });

  testWidgets('abre edição e exclusão atualiza o estado vazio', (tester) async {
    final controle = _ControleFake([
      _tarefa(
        id: 1,
        titulo: 'Excluir pela tela Hoje',
        horario: HorarioTarefa(hora: 10, minuto: 0),
      ),
    ]);

    await tester.pumpWidget(_app(controle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir pela tela Hoje'));
    await tester.pumpAndSettle();
    expect(find.text('Editar tarefa'), findsOneWidget);

    await tester.ensureVisible(find.text('Excluir tarefa'));
    await tester.tap(find.text('Excluir tarefa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(controle.tarefas, isEmpty);
    expect(find.text('Nenhuma tarefa para hoje.'), findsOneWidget);
  });

  testWidgets('exibe erro com nova tentativa e depois estado vazio', (
    tester,
  ) async {
    final controle = _ControleFake()..falharConsulta = true;

    await tester.pumpWidget(_app(controle));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar as tarefas de hoje.'),
      findsOneWidget,
    );

    controle.falharConsulta = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma tarefa para hoje.'), findsOneWidget);
    expect(find.text('0 de 0 tarefas concluídas'), findsOneWidget);
  });

  testWidgets('ignora resposta antiga após uma revisão mais recente', (
    tester,
  ) async {
    const chave = ValueKey('hoje');
    final primeira = Completer<List<Tarefa>>();
    final segunda = Completer<List<Tarefa>>();
    final controle = _ControleFake();
    controle.aoConsultar = (_) =>
        controle.consultasPorData == 1 ? primeira.future : segunda.future;

    await tester.pumpWidget(_app(controle, key: chave));
    await tester.pump();
    expect(find.text('Carregando tarefas de hoje...'), findsOneWidget);
    await tester.pumpWidget(_app(controle, key: chave, revisao: 1));
    await tester.pump();

    segunda.complete([
      _tarefa(
        id: 2,
        titulo: 'Resposta mais recente',
        horario: HorarioTarefa(hora: 14, minuto: 0),
      ),
    ]);
    await tester.pump();
    primeira.complete([
      _tarefa(
        id: 1,
        titulo: 'Resposta obsoleta',
        horario: HorarioTarefa(hora: 8, minuto: 0),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Resposta mais recente'), findsOneWidget);
    expect(find.text('Resposta obsoleta'), findsNothing);
  });

  testWidgets('permanece utilizável em tela estreita', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controle = _ControleFake([
      _tarefa(
        id: 1,
        titulo: 'Uma tarefa com título longo para validar a quebra de linha',
        horario: HorarioTarefa(hora: 8, minuto: 30),
        estimativa: const Duration(minutes: 95),
      ),
    ]);
    var abriuCadastro = false;

    await tester.pumpWidget(
      _app(
        controle,
        onNovaTarefa: () async {
          abriuCadastro = true;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('adicionar_tarefa_hoje')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('adicionar_tarefa_hoje')));
    await tester.pump();

    expect(abriuCadastro, isTrue);
    expect(tester.takeException(), isNull);
  });
}
