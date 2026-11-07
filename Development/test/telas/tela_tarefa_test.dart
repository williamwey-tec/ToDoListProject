import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:to_do_list/control/control_tarefa.dart';
import 'package:to_do_list/main.dart';
import 'package:to_do_list/model/tarefa.dart';
import 'package:to_do_list/services/banco_service.dart';
import 'package:to_do_list/telas/tela_tarefa.dart';
import 'package:to_do_list/telas/tela_tarefas_salvas.dart';
import 'package:to_do_list/tema/tema_app.dart';
import 'package:to_do_list/widgets/card_tarefa.dart';

class _OperacoesTarefaFake implements OperacoesTarefa {
  final List<Tarefa> _tarefas = [];
  int _proximoIdentificador = 1;

  @override
  Future<Tarefa> criarTarefa(Tarefa tarefa) async {
    final criada = Tarefa(
      identificador: _proximoIdentificador++,
      titulo: tarefa.titulo.trim(),
      descricao: tarefa.descricao,
      data: tarefa.data,
      horario: tarefa.horario,
      duracaoEstimada: tarefa.duracaoEstimada,
      tempoRegistrado: tarefa.tempoRegistrado,
      prioridade: tarefa.prioridade,
      categoria: tarefa.categoria,
      status: tarefa.status,
    );
    _tarefas.add(criada);
    return criada;
  }

  @override
  Future<Tarefa> editarTarefa(int identificador, Tarefa dadosEditados) async {
    final indice = _tarefas.indexWhere(
      (tarefa) => tarefa.identificador == identificador,
    );
    if (indice < 0) throw TarefaNaoEncontradaException(identificador);
    final atual = _tarefas[indice];
    final editada = Tarefa(
      identificador: identificador,
      titulo: dadosEditados.titulo.trim(),
      descricao: dadosEditados.descricao,
      data: dadosEditados.data,
      horario: dadosEditados.horario,
      duracaoEstimada: dadosEditados.duracaoEstimada,
      tempoRegistrado: atual.tempoRegistrado,
      prioridade: dadosEditados.prioridade,
      categoria: dadosEditados.categoria,
      status: atual.status,
    );
    _tarefas[indice] = editada;
    return editada;
  }

  @override
  Future<Tarefa> concluirTarefa(int identificador) async {
    final indice = _tarefas.indexWhere(
      (tarefa) => tarefa.identificador == identificador,
    );
    if (indice < 0) throw TarefaNaoEncontradaException(identificador);
    return _tarefas[indice] = _tarefas[indice].copiarComStatus(
      StatusTarefa.concluida,
    );
  }

  @override
  Future<Tarefa> reabrirTarefa(int identificador) async {
    final indice = _tarefas.indexWhere(
      (tarefa) => tarefa.identificador == identificador,
    );
    if (indice < 0) throw TarefaNaoEncontradaException(identificador);
    return _tarefas[indice] = _tarefas[indice].copiarComStatus(
      StatusTarefa.pendente,
    );
  }

  @override
  Future<void> excluirTarefa(int identificador) async {
    _tarefas.removeWhere((tarefa) => tarefa.identificador == identificador);
  }

  @override
  Future<Tarefa?> consultarTarefaPorId(int identificador) async {
    for (final tarefa in _tarefas) {
      if (tarefa.identificador == identificador) return tarefa;
    }
    return null;
  }

  @override
  Future<List<Tarefa>> consultarTarefasPorData(DateTime data) async {
    return _tarefas
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
    final inicio = DateTime(
      dataInicial.year,
      dataInicial.month,
      dataInicial.day,
    );
    final fim = DateTime(dataFinal.year, dataFinal.month, dataFinal.day);
    return _tarefas
        .where(
          (tarefa) =>
              !tarefa.data.isBefore(inicio) && !tarefa.data.isAfter(fim),
        )
        .toList(growable: false);
  }
}

void main() {
  sqfliteFfiInit();

  late _OperacoesTarefaFake controle;

  setUp(() => controle = _OperacoesTarefaFake());

  Finder campo(String chave) => find.descendant(
    of: find.byKey(Key(chave)),
    matching: find.byType(TextFormField),
  );

  Future<void> abrirTela(WidgetTester tester, Widget tela) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.claro,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).push<void>(MaterialPageRoute<void>(builder: (_) => tela)),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> aguardarOperacao(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  testWidgets('rejeita formulário inválido sem persistir', (tester) async {
    await abrirTela(
      tester,
      TelaTarefa(controleTarefa: controle, dataInicial: DateTime(2026, 11, 9)),
    );

    await tester.enterText(campo('campo_duracao'), '0');
    await tester.ensureVisible(find.text('Salvar tarefa'));
    await tester.tap(find.text('Salvar tarefa'));
    await tester.pump();

    expect(find.text('Informe um título.'), findsOneWidget);
    expect(find.text('Use minutos maiores que zero.'), findsOneWidget);
    expect(
      await controle.consultarTarefasPorData(DateTime(2026, 11, 9)),
      isEmpty,
    );
  });

  testWidgets('cria tarefa válida com todos os campos do formulário', (
    tester,
  ) async {
    await abrirTela(
      tester,
      TelaTarefa(controleTarefa: controle, dataInicial: DateTime(2026, 11, 9)),
    );

    await tester.enterText(campo('campo_titulo'), 'Preparar apresentação');
    await tester.enterText(campo('campo_descricao'), 'Revisar os slides');
    await tester.enterText(campo('campo_duracao'), '45');
    await tester.enterText(campo('campo_categoria'), 'Faculdade');
    await tester.tap(find.text('Alta'));
    await tester.ensureVisible(find.text('Salvar tarefa'));
    await tester.tap(find.text('Salvar tarefa'));
    await aguardarOperacao(tester);

    final tarefas = await controle.consultarTarefasPorData(
      DateTime(2026, 11, 9),
    );
    expect(tarefas, hasLength(1));
    expect(tarefas.single.titulo, 'Preparar apresentação');
    expect(tarefas.single.descricao, 'Revisar os slides');
    expect(tarefas.single.duracaoEstimada, const Duration(minutes: 45));
    expect(tarefas.single.categoria, 'Faculdade');
    expect(tarefas.single.prioridade, PrioridadeTarefa.alta);
    expect(tarefas.single.horario, isNotNull);
  });

  testWidgets('edita preservando tempo e situação do controle', (tester) async {
    final original = await controle.criarTarefa(
      Tarefa(
        titulo: 'Título original',
        data: DateTime(2026, 11, 10),
        horario: HorarioTarefa(hora: 14, minuto: 0),
        duracaoEstimada: const Duration(minutes: 30),
        tempoRegistrado: const Duration(minutes: 17),
        prioridade: PrioridadeTarefa.alta,
        status: StatusTarefa.pausada,
      ),
    );
    await abrirTela(
      tester,
      TelaTarefa(controleTarefa: controle, tarefa: original),
    );

    await tester.enterText(campo('campo_titulo'), 'Título atualizado');
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.tap(find.text('Salvar alterações'));
    await aguardarOperacao(tester);

    final editada = await controle.consultarTarefaPorId(
      original.identificador!,
    );
    expect(editada?.titulo, 'Título atualizado');
    expect(editada?.tempoRegistrado, const Duration(minutes: 17));
    expect(editada?.status, StatusTarefa.pausada);
  });

  testWidgets('cancelar exclusão mantém dados e confirmar remove', (
    tester,
  ) async {
    final original = await controle.criarTarefa(
      Tarefa(
        titulo: 'Excluir com confirmação',
        data: DateTime(2026, 11, 11),
        horario: HorarioTarefa(hora: 9, minuto: 0),
        duracaoEstimada: const Duration(minutes: 20),
      ),
    );
    await abrirTela(
      tester,
      TelaTarefa(controleTarefa: controle, tarefa: original),
    );

    await tester.ensureVisible(find.text('Excluir tarefa'));
    await tester.tap(find.text('Excluir tarefa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(
      await controle.consultarTarefaPorId(original.identificador!),
      isNotNull,
    );

    await tester.tap(find.text('Excluir tarefa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await aguardarOperacao(tester);
    expect(
      await controle.consultarTarefaPorId(original.identificador!),
      isNull,
    );
  });

  testWidgets('lista abre uma tarefa persistida para edição', (tester) async {
    await controle.criarTarefa(
      Tarefa(
        titulo: 'Persistida após reinício',
        data: DateTime(2026, 11, 12),
        horario: HorarioTarefa(hora: 8, minuto: 30),
        duracaoEstimada: const Duration(minutes: 25),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.claro,
        home: TelaTarefasSalvas(controleTarefa: controle),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Persistida após reinício'), findsOneWidget);
    expect(find.text('12/11/2026 · 08:30 · 25 min'), findsOneWidget);
    await tester.tap(find.text('Persistida após reinício'));
    await tester.pumpAndSettle();
    expect(find.text('Editar tarefa'), findsOneWidget);
  });

  testWidgets('atalhos de Hoje e Calendário abrem criação na data esperada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MyApp(controleTarefa: controle, relogio: () => DateTime(2026, 10, 8)),
    );
    await tester.tap(find.byTooltip('Nova tarefa'));
    await tester.pumpAndSettle();
    expect(find.text('Nova tarefa'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nova tarefa'));
    await tester.pumpAndSettle();

    final campoData = tester.widget<TextFormField>(campo('campo_data'));
    expect(campoData.controller?.text, '05/10/2026');

    await tester.enterText(campo('campo_titulo'), 'Tarefa pelo calendário');
    await tester.enterText(campo('campo_duracao'), '25');
    await tester.ensureVisible(find.text('Salvar tarefa'));
    await tester.tap(find.text('Salvar tarefa'));
    await tester.pumpAndSettle();

    expect(find.text('Segunda, 5 de outubro'), findsOneWidget);
    expect(find.text('Tarefa pelo calendário'), findsOneWidget);
    expect(find.byKey(const ValueKey('marcador_2026-10-5')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.checklist_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Segunda, 5 de outubro'), findsOneWidget);
    expect(find.text('Tarefa pelo calendário'), findsOneWidget);
  });

  testWidgets('alterações em Hoje e Calendário permanecem sincronizadas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final criada = await controle.criarTarefa(
      Tarefa(
        titulo: 'Tarefa compartilhada',
        data: DateTime(2026, 10, 8),
        horario: HorarioTarefa(hora: 9, minuto: 0),
        duracaoEstimada: const Duration(minutes: 30),
      ),
    );
    await tester.pumpWidget(
      MyApp(controleTarefa: controle, relogio: () => DateTime(2026, 10, 8, 10)),
    );
    await tester.pumpAndSettle();

    final cardHoje = find.ancestor(
      of: find.text('Tarefa compartilhada'),
      matching: find.byType(CardTarefa),
    );
    await tester.tap(
      find.descendant(of: cardHoje, matching: find.byType(IconButton)),
    );
    await tester.pumpAndSettle();
    expect(
      (await controle.consultarTarefaPorId(criada.identificador!))?.status,
      StatusTarefa.concluida,
    );
    expect(find.text('1 de 1 tarefas concluídas'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Tarefa compartilhada'), findsOneWidget);
    expect(find.text('1 concluída'), findsOneWidget);

    await tester.tap(find.text('Tarefa compartilhada'));
    await tester.pumpAndSettle();
    await tester.enterText(campo('campo_titulo'), 'Tarefa movida');
    await tester.tap(campo('campo_data'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('9'),
      ),
    );
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(find.text('Tarefa compartilhada'), findsNothing);
    expect(find.byKey(const ValueKey('marcador_2026-10-9')), findsOneWidget);
    await tester.tap(find.text('9'));
    await tester.pumpAndSettle();
    expect(find.text('Tarefa movida'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.checklist_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Tarefa movida'), findsNothing);
    expect(find.text('Nenhuma tarefa para hoje.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarefa movida'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Excluir tarefa'));
    await tester.tap(find.text('Excluir tarefa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Tarefa movida'), findsNothing);
    expect(
      find.text('Nenhuma tarefa planejada para este dia.'),
      findsOneWidget,
    );
  });

  testWidgets('formulário permanece rolável em tela estreita', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await abrirTela(
      tester,
      TelaTarefa(controleTarefa: controle, dataInicial: DateTime(2026, 11, 9)),
    );
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Salvar tarefa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('SQLite mantém registro depois de fechar e reabrir', () async {
    final diretorio = await Directory.systemTemp.createTemp(
      'flow_task_ft06_reabertura_',
    );
    final caminhoBanco = path.join(diretorio.path, 'teste.db');
    var bancoReal = BancoService(
      caminhoBanco: caminhoBanco,
      fabricaBanco: databaseFactoryFfi,
    );
    try {
      var controleReal = ControlTarefa(banco: bancoReal);
      await controleReal.criarTarefa(
        Tarefa(
          titulo: 'Persistida após reinício',
          data: DateTime(2026, 11, 12),
          horario: HorarioTarefa(hora: 8, minuto: 30),
          duracaoEstimada: const Duration(minutes: 25),
        ),
      );
      await bancoReal.fechar();

      bancoReal = BancoService(
        caminhoBanco: caminhoBanco,
        fabricaBanco: databaseFactoryFfi,
      );
      controleReal = ControlTarefa(banco: bancoReal);
      final recuperadas = await controleReal.consultarTarefasPorData(
        DateTime(2026, 11, 12),
      );

      expect(recuperadas, hasLength(1));
      expect(recuperadas.single.titulo, 'Persistida após reinício');
    } finally {
      await bancoReal.fechar();
      if (await diretorio.exists()) {
        await diretorio.delete(recursive: true);
      }
    }
  });
}
