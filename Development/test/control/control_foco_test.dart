import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:to_do_list/control/control_foco.dart';
import 'package:to_do_list/control/control_tarefa.dart';
import 'package:to_do_list/model/sessao_foco.dart';
import 'package:to_do_list/model/tarefa.dart';
import 'package:to_do_list/services/banco_service.dart';

void main() {
  sqfliteFfiInit();

  late Directory diretorio;
  late String caminhoBanco;
  late BancoService banco;
  late DateTime agora;
  late ControlFoco foco;

  setUp(() async {
    diretorio = await Directory.systemTemp.createTemp('flow_task_foco_');
    caminhoBanco = path.join(diretorio.path, 'foco.db');
    banco = BancoService(
      caminhoBanco: caminhoBanco,
      fabricaBanco: databaseFactoryFfi,
    );
    agora = DateTime(2026, 11, 7, 10);
    foco = ControlFoco(banco: banco, relogio: () => agora);
  });

  tearDown(() async {
    await banco.fechar();
    if (await diretorio.exists()) {
      await diretorio.delete(recursive: true);
    }
  });

  Future<Tarefa> inserir(
    String titulo, {
    int hora = 10,
    Duration registrado = Duration.zero,
  }) async {
    final id = await banco.inserirTarefa(
      Tarefa(
        titulo: titulo,
        data: DateTime(2026, 11, 7),
        horario: HorarioTarefa(hora: hora, minuto: 0),
        duracaoEstimada: const Duration(minutes: 45),
        tempoRegistrado: registrado,
      ),
    );
    return (await banco.consultarTarefaPorId(id))!;
  }

  test(
    'mantém sessão ativa no reinício e pausa exclui intervalos parados',
    () async {
      final tarefa = await inserir(
        'Persistir foco',
        registrado: const Duration(minutes: 5),
      );
      await foco.selecionarTarefa(tarefa.identificador!);
      await foco.iniciar();

      agora = DateTime(2026, 11, 7, 10, 12);
      await banco.fechar();
      banco = BancoService(
        caminhoBanco: caminhoBanco,
        fabricaBanco: databaseFactoryFfi,
      );
      foco = ControlFoco(banco: banco, relogio: () => agora);

      final restaurado = await foco.consultarEstado();
      expect(restaurado.estaEmAndamento, isTrue);
      expect(restaurado.tempoUtilizadoEm(agora), const Duration(minutes: 17));

      await foco.pausar();
      agora = DateTime(2026, 11, 7, 10, 22);
      final aindaPausado = await foco.consultarEstado();
      expect(aindaPausado.tempoUtilizadoEm(agora), const Duration(minutes: 17));

      await foco.retomar();
      agora = DateTime(2026, 11, 7, 10, 25);
      await foco.pausar();
      final persistida = await banco.consultarTarefaPorId(
        tarefa.identificador!,
      );
      expect(persistida?.tempoRegistrado, const Duration(minutes: 20));
    },
  );

  test(
    'garante exclusividade e não soma duas vezes sob ações concorrentes',
    () async {
      final primeira = await inserir('Primeira');
      final segunda = await inserir('Segunda', hora: 11);

      final inicios = await Future.wait([
        banco.iniciarFoco(primeira.identificador!, agora),
        banco.iniciarFoco(segunda.identificador!, agora),
      ]);
      expect(inicios, contains(ResultadoTransicaoFoco.realizada));
      expect(inicios, contains(ResultadoTransicaoFoco.outraTarefaEmAndamento));

      agora = DateTime(2026, 11, 7, 10, 10);
      final pausas = await Future.wait([
        banco.pausarFoco(agora),
        banco.pausarFoco(agora),
      ]);
      expect(pausas, contains(ResultadoTransicaoFoco.realizada));
      expect(pausas, contains(ResultadoTransicaoFoco.jaPausada));

      final primeiraPersistida = await banco.consultarTarefaPorId(
        primeira.identificador!,
      );
      final segundaPersistida = await banco.consultarTarefaPorId(
        segunda.identificador!,
      );
      expect([
        primeiraPersistida!.tempoRegistrado,
        segundaPersistida!.tempoRegistrado,
      ], contains(const Duration(minutes: 10)));
      expect(
        primeiraPersistida.tempoRegistrado + segundaPersistida.tempoRegistrado,
        const Duration(minutes: 10),
      );
    },
  );

  test(
    'conclusão pelo fluxo existente consolida o tempo e encerra a sessão',
    () async {
      final tarefa = await inserir('Concluir fora do foco');
      final tarefas = ControlTarefa(banco: banco, relogio: () => agora);
      await foco.selecionarTarefa(tarefa.identificador!);
      await foco.iniciar();
      agora = DateTime(2026, 11, 7, 10, 8);

      final concluida = await tarefas.concluirTarefa(tarefa.identificador!);

      expect(concluida.status, StatusTarefa.concluida);
      expect(concluida.tempoRegistrado, const Duration(minutes: 8));
      expect(await banco.consultarSessaoFoco(), isNull);
    },
  );

  test('exclusão pelo fluxo existente remove a sessão sem órfão', () async {
    final tarefa = await inserir('Excluir fora do foco');
    final tarefas = ControlTarefa(banco: banco, relogio: () => agora);
    await foco.selecionarTarefa(tarefa.identificador!);
    await foco.iniciar();
    agora = DateTime(2026, 11, 7, 10, 4);

    await tarefas.excluirTarefa(tarefa.identificador!);

    expect(await banco.consultarTarefaPorId(tarefa.identificador!), isNull);
    expect(await banco.consultarSessaoFoco(), isNull);
  });

  test('Hoje projeta tempo ativo e edição preserva tempo e situação', () async {
    final tarefa = await inserir('Integração Hoje');
    final tarefas = ControlTarefa(banco: banco, relogio: () => agora);
    await foco.selecionarTarefa(tarefa.identificador!);
    await foco.iniciar();
    agora = DateTime(2026, 11, 7, 10, 7);

    final duranteFoco = await tarefas.consultarTarefasPorData(agora);
    expect(duranteFoco.single.tempoRegistrado, const Duration(minutes: 7));

    await foco.pausar();
    final editada = await tarefas.editarTarefa(
      tarefa.identificador!,
      Tarefa(
        titulo: 'Integração editada',
        data: DateTime(2026, 11, 8),
        horario: HorarioTarefa(hora: 14, minuto: 0),
        duracaoEstimada: const Duration(hours: 1),
        tempoRegistrado: const Duration(hours: 99),
        status: StatusTarefa.concluida,
      ),
    );

    expect(editada.data, DateTime(2026, 11, 8));
    expect(editada.tempoRegistrado, const Duration(minutes: 7));
    expect(editada.status, StatusTarefa.pendente);
  });

  test('migra banco v1 sem destruir tarefas existentes', () async {
    await banco.fechar();
    final legado = await databaseFactoryFfi.openDatabase(
      caminhoBanco,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE tarefas (
              identificador INTEGER PRIMARY KEY AUTOINCREMENT,
              titulo TEXT NOT NULL,
              descricao TEXT,
              data_civil TEXT NOT NULL,
              horario_minutos INTEGER,
              duracao_estimada_microssegundos INTEGER,
              tempo_registrado_microssegundos INTEGER NOT NULL,
              prioridade TEXT NOT NULL,
              categoria TEXT,
              situacao TEXT NOT NULL
            )
          ''');
          await db.insert('tarefas', {
            'titulo': 'Legada',
            'data_civil': '2026-11-07',
            'horario_minutos': 600,
            'duracao_estimada_microssegundos': const Duration(
              minutes: 30,
            ).inMicroseconds,
            'tempo_registrado_microssegundos': const Duration(
              minutes: 3,
            ).inMicroseconds,
            'prioridade': 'media',
            'situacao': 'pendente',
          });
        },
      ),
    );
    await legado.close();

    banco = BancoService(
      caminhoBanco: caminhoBanco,
      fabricaBanco: databaseFactoryFfi,
    );
    foco = ControlFoco(banco: banco, relogio: () => agora);
    final tarefa = await banco.consultarTarefaPorId(1);
    await foco.selecionarTarefa(1);

    expect(tarefa?.titulo, 'Legada');
    expect(tarefa?.tempoRegistrado, const Duration(minutes: 3));
    expect((await banco.consultarSessaoFoco())?.tarefaIdentificador, 1);
  });
}
