import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:to_do_list/control/control_tarefa.dart';
import 'package:to_do_list/model/tarefa.dart';
import 'package:to_do_list/services/banco_service.dart';

void main() {
  sqfliteFfiInit();

  final agoraFixo = DateTime(2026, 11, 6, 10);
  late Directory diretorioTemporario;
  late BancoService banco;
  late ControlTarefa control;

  setUp(() async {
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'flow_task_control_',
    );
    banco = BancoService(
      caminhoBanco: path.join(diretorioTemporario.path, 'teste.db'),
      fabricaBanco: databaseFactoryFfi,
    );
    control = ControlTarefa(banco: banco, relogio: () => agoraFixo);
  });

  tearDown(() async {
    await banco.fechar();
    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  Tarefa novaTarefa({
    String titulo = 'Estudar FT-05',
    DateTime? data,
    HorarioTarefa? horario,
    Duration? duracaoEstimada,
    Duration tempoRegistrado = Duration.zero,
    StatusTarefa status = StatusTarefa.pendente,
  }) {
    return Tarefa(
      titulo: titulo,
      data: data ?? DateTime(2026, 11, 6),
      horario: horario ?? HorarioTarefa(hora: 11, minuto: 0),
      duracaoEstimada: duracaoEstimada ?? const Duration(minutes: 30),
      tempoRegistrado: tempoRegistrado,
      status: status,
    );
  }

  test('cria com ID, apara o título e mantém padrões do modelo', () async {
    final criada = await control.criarTarefa(
      novaTarefa(titulo: '  Estudar FT-05  '),
    );

    expect(criada.identificador, greaterThan(0));
    expect(criada.titulo, 'Estudar FT-05');
    expect(criada.prioridade, PrioridadeTarefa.media);
    expect(criada.status, StatusTarefa.pendente);

    final persistida = await banco.consultarTarefaPorId(criada.identificador!);
    expect(persistida?.titulo, 'Estudar FT-05');
  });

  test('rejeita dados inválidos sem inserir registros', () async {
    for (final invalida in [
      novaTarefa(titulo: '   '),
      Tarefa(
        titulo: 'Sem horário',
        data: DateTime(2026, 11, 6),
        duracaoEstimada: const Duration(minutes: 1),
      ),
      novaTarefa(duracaoEstimada: Duration.zero),
      novaTarefa(duracaoEstimada: const Duration(seconds: -1)),
    ]) {
      await expectLater(
        control.criarTarefa(invalida),
        throwsA(isA<ValidacaoTarefaException>()),
      );
    }

    expect(
      await control.consultarTarefasPorData(DateTime(2026, 11, 6)),
      isEmpty,
    );
  });

  test(
    'calcula atraso na fronteira e nunca atrasa concluída ou pausada',
    () async {
      final atrasada = await control.criarTarefa(
        novaTarefa(horario: HorarioTarefa(hora: 9, minuto: 59)),
      );
      final naFronteira = await control.criarTarefa(
        novaTarefa(horario: HorarioTarefa(hora: 10, minuto: 0)),
      );
      final concluida = await control.criarTarefa(
        novaTarefa(
          horario: HorarioTarefa(hora: 8, minuto: 0),
          status: StatusTarefa.concluida,
        ),
      );
      final pausada = await control.criarTarefa(
        novaTarefa(
          horario: HorarioTarefa(hora: 8, minuto: 30),
          status: StatusTarefa.pausada,
        ),
      );

      expect(atrasada.status, StatusTarefa.atrasada);
      expect(naFronteira.status, StatusTarefa.pendente);
      expect(concluida.status, StatusTarefa.concluida);
      expect(pausada.status, StatusTarefa.pausada);

      final atrasadaNoBanco = await banco.consultarTarefaPorId(
        atrasada.identificador!,
      );
      expect(atrasadaNoBanco?.status, StatusTarefa.pendente);
    },
  );

  test('edita campos permitidos e preserva ID, tempo e situação', () async {
    final original = await control.criarTarefa(
      novaTarefa(
        tempoRegistrado: const Duration(minutes: 17),
        status: StatusTarefa.pausada,
      ),
    );

    final editada = await control.editarTarefa(
      original.identificador!,
      Tarefa(
        identificador: 999,
        titulo: '  Revisar implementação  ',
        descricao: 'Campos editáveis',
        data: DateTime(2026, 11, 7),
        horario: HorarioTarefa(hora: 14, minuto: 30),
        duracaoEstimada: const Duration(hours: 1),
        tempoRegistrado: const Duration(hours: 99),
        prioridade: PrioridadeTarefa.alta,
        categoria: 'Faculdade',
        status: StatusTarefa.concluida,
      ),
    );

    expect(editada.identificador, original.identificador);
    expect(editada.titulo, 'Revisar implementação');
    expect(editada.tempoRegistrado, const Duration(minutes: 17));
    expect(editada.status, StatusTarefa.pausada);
    expect(editada.descricao, 'Campos editáveis');
    expect(editada.categoria, 'Faculdade');
    expect(editada.prioridade, PrioridadeTarefa.alta);
  });

  test('edição recalcula atraso sem persistir o estado derivado', () async {
    final atrasada = await control.criarTarefa(
      novaTarefa(
        horario: HorarioTarefa(hora: 9, minuto: 0),
        tempoRegistrado: const Duration(minutes: 12),
      ),
    );
    expect(atrasada.status, StatusTarefa.atrasada);

    await expectLater(
      control.editarTarefa(
        atrasada.identificador!,
        novaTarefa(duracaoEstimada: Duration.zero),
      ),
      throwsA(isA<ValidacaoTarefaException>()),
    );

    final editada = await control.editarTarefa(
      atrasada.identificador!,
      novaTarefa(horario: HorarioTarefa(hora: 10, minuto: 0)),
    );

    expect(editada.status, StatusTarefa.pendente);
    expect(editada.tempoRegistrado, const Duration(minutes: 12));
    final persistida = await banco.consultarTarefaPorId(
      atrasada.identificador!,
    );
    expect(persistida?.status, StatusTarefa.pendente);
    expect(persistida?.tempoRegistrado, const Duration(minutes: 12));
  });

  test('conclui e reabre preservando o tempo e recalculando atraso', () async {
    final criada = await control.criarTarefa(
      novaTarefa(
        horario: HorarioTarefa(hora: 9, minuto: 0),
        tempoRegistrado: const Duration(minutes: 22),
      ),
    );

    final concluida = await control.concluirTarefa(criada.identificador!);
    final reaberta = await control.reabrirTarefa(criada.identificador!);

    expect(concluida.status, StatusTarefa.concluida);
    expect(concluida.tempoRegistrado, const Duration(minutes: 22));
    expect(reaberta.status, StatusTarefa.atrasada);
    expect(reaberta.tempoRegistrado, const Duration(minutes: 22));

    final persistida = await banco.consultarTarefaPorId(criada.identificador!);
    expect(persistida?.status, StatusTarefa.pendente);
    expect(persistida?.tempoRegistrado, const Duration(minutes: 22));
  });

  test(
    'consulta legado incompleto, ordena e trata inexistência com clareza',
    () async {
      final legadoId = await banco.inserirTarefa(
        Tarefa(titulo: 'Legada', data: DateTime(2026, 11, 6)),
      );
      final tarde = await control.criarTarefa(
        novaTarefa(
          titulo: 'Tarde',
          horario: HorarioTarefa(hora: 14, minuto: 0),
        ),
      );
      final manha = await control.criarTarefa(
        novaTarefa(titulo: 'Manhã', horario: HorarioTarefa(hora: 8, minuto: 0)),
      );

      final porId = await control.consultarTarefaPorId(legadoId);
      final doDia = await control.consultarTarefasPorData(
        DateTime(2026, 11, 6, 23, 59),
      );
      final doIntervalo = await control.consultarTarefasPorIntervalo(
        DateTime(2026, 11, 6),
        DateTime(2026, 11, 6),
      );

      expect(porId?.horario, isNull);
      expect(porId?.duracaoEstimada, isNull);
      expect(doDia.map((tarefa) => tarefa.identificador), [
        manha.identificador,
        tarde.identificador,
        legadoId,
      ]);
      expect(
        doIntervalo.map((tarefa) => tarefa.identificador),
        doDia.map((tarefa) => tarefa.identificador),
      );
      expect(await control.consultarTarefaPorId(99999), isNull);
      await expectLater(
        control.excluirTarefa(99999),
        throwsA(isA<TarefaNaoEncontradaException>()),
      );
      await expectLater(
        control.editarTarefa(99999, novaTarefa()),
        throwsA(isA<TarefaNaoEncontradaException>()),
      );

      await control.excluirTarefa(tarde.identificador!);
      expect(await control.consultarTarefaPorId(tarde.identificador!), isNull);
    },
  );
}
