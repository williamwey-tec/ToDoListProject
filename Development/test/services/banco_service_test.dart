import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:to_do_list/model/tarefa.dart';
import 'package:to_do_list/services/banco_service.dart';

void main() {
  sqfliteFfiInit();

  late Directory diretorioTemporario;
  late String caminhoBanco;
  late BancoService banco;

  setUp(() async {
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'flow_task_banco_',
    );
    caminhoBanco = path.join(diretorioTemporario.path, 'teste.db');
    banco = BancoService(
      caminhoBanco: caminhoBanco,
      fabricaBanco: databaseFactoryFfi,
    );
  });

  tearDown(() async {
    await banco.fechar();
    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  test('insere com ID gerado e recupera todos os campos', () async {
    final original = Tarefa(
      titulo: "Preparar revisão d'arquitetura",
      descricao: 'Conferir persistência completa',
      data: DateTime(2026, 11, 6, 23, 59),
      horario: HorarioTarefa(hora: 14, minuto: 35),
      duracaoEstimada: const Duration(hours: 1, minutes: 25, microseconds: 7),
      tempoRegistrado: const Duration(minutes: 42, microseconds: 3),
      prioridade: PrioridadeTarefa.alta,
      categoria: 'Faculdade',
      status: StatusTarefa.pausada,
    );

    final identificador = await banco.inserirTarefa(original);
    final recuperada = await banco.consultarTarefaPorId(identificador);

    expect(identificador, greaterThan(0));
    expect(recuperada, isNotNull);
    expect(recuperada!.identificador, identificador);
    expect(recuperada.titulo, original.titulo);
    expect(recuperada.descricao, original.descricao);
    expect(recuperada.data, DateTime(2026, 11, 6));
    expect(recuperada.horario?.hora, 14);
    expect(recuperada.horario?.minuto, 35);
    expect(recuperada.duracaoEstimada, original.duracaoEstimada);
    expect(recuperada.tempoRegistrado, original.tempoRegistrado);
    expect(recuperada.prioridade, original.prioridade);
    expect(recuperada.categoria, original.categoria);
    expect(recuperada.status, original.status);
  });

  test('persiste após fechar e reabrir e preserva opcionais nulos', () async {
    final identificador = await banco.inserirTarefa(
      Tarefa(
        titulo: 'Tarefa sem opcionais',
        data: DateTime(2026, 11, 7),
        tempoRegistrado: const Duration(seconds: 17),
      ),
    );

    await banco.fechar();
    banco = BancoService(
      caminhoBanco: caminhoBanco,
      fabricaBanco: databaseFactoryFfi,
    );

    final recuperada = await banco.consultarTarefaPorId(identificador);

    expect(recuperada, isNotNull);
    expect(recuperada!.descricao, isNull);
    expect(recuperada.horario, isNull);
    expect(recuperada.duracaoEstimada, isNull);
    expect(recuperada.categoria, isNull);
    expect(recuperada.tempoRegistrado, const Duration(seconds: 17));
    expect(recuperada.prioridade, PrioridadeTarefa.media);
    expect(recuperada.status, StatusTarefa.pendente);
  });

  test(
    'consulta dia e intervalo inclusivo sem incluir dias indevidos',
    () async {
      Future<int> inserir(
        String titulo,
        DateTime data, {
        HorarioTarefa? horario,
      }) {
        return banco.inserirTarefa(
          Tarefa(titulo: titulo, data: data, horario: horario),
        );
      }

      await inserir('dia anterior', DateTime(2026, 11, 7));
      final semHorario = await inserir('sem horário', DateTime(2026, 11, 8));
      final tarde = await inserir(
        'à tarde',
        DateTime(2026, 11, 8),
        horario: HorarioTarefa(hora: 14, minuto: 0),
      );
      final manha = await inserir(
        'de manhã',
        DateTime(2026, 11, 8),
        horario: HorarioTarefa(hora: 9, minuto: 30),
      );
      final limiteFinal = await inserir('limite final', DateTime(2026, 11, 9));
      await inserir('dia posterior', DateTime(2026, 11, 10));

      final doDia = await banco.consultarTarefasPorData(
        DateTime(2026, 11, 8, 22, 15),
      );
      final doIntervalo = await banco.consultarTarefasPorIntervalo(
        DateTime(2026, 11, 8, 23, 59),
        DateTime(2026, 11, 9, 0, 1),
      );

      expect(doDia.map((tarefa) => tarefa.identificador), [
        manha,
        tarde,
        semHorario,
      ]);
      expect(doIntervalo.map((tarefa) => tarefa.identificador), [
        manha,
        tarde,
        semHorario,
        limiteFinal,
      ]);
    },
  );

  test('atualiza e exclui pelo ID sem afetar outros registros', () async {
    final primeiroId = await banco.inserirTarefa(
      Tarefa(titulo: 'Primeira', data: DateTime(2026, 11, 8)),
    );
    final segundoId = await banco.inserirTarefa(
      Tarefa(titulo: 'Segunda', data: DateTime(2026, 11, 9)),
    );

    final alterados = await banco.atualizarTarefa(
      primeiroId,
      Tarefa(
        identificador: segundoId,
        titulo: 'Primeira atualizada',
        descricao: 'Somente este registro muda',
        data: DateTime(2026, 12, 1),
        horario: HorarioTarefa(hora: 8, minuto: 5),
        duracaoEstimada: const Duration(minutes: 50),
        tempoRegistrado: const Duration(minutes: 12),
        prioridade: PrioridadeTarefa.baixa,
        categoria: 'Pessoal',
        status: StatusTarefa.concluida,
      ),
    );

    final primeiroAtualizado = await banco.consultarTarefaPorId(primeiroId);
    final segundoIntacto = await banco.consultarTarefaPorId(segundoId);

    expect(alterados, 1);
    expect(primeiroAtualizado?.identificador, primeiroId);
    expect(primeiroAtualizado?.titulo, 'Primeira atualizada');
    expect(primeiroAtualizado?.status, StatusTarefa.concluida);
    expect(segundoIntacto?.titulo, 'Segunda');
    expect(segundoIntacto?.data, DateTime(2026, 11, 9));

    expect(await banco.excluirTarefa(primeiroId), 1);
    expect(await banco.consultarTarefaPorId(primeiroId), isNull);
    expect(await banco.consultarTarefaPorId(segundoId), isNotNull);
    expect(await banco.excluirTarefa(primeiroId), 0);
  });
}
