import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:to_do_list/services/banco_service.dart';

Future<void> _criarBancoLegado(String caminho, int versao) async {
  final banco = await databaseFactoryFfi.openDatabase(
    caminho,
    options: OpenDatabaseOptions(
      version: versao,
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
            situacao TEXT NOT NULL,
            CHECK (horario_minutos IS NULL OR horario_minutos BETWEEN 0 AND 1439),
            CHECK (prioridade IN ('baixa', 'media', 'alta')),
            CHECK (situacao IN ('pendente', 'concluida', 'atrasada', 'pausada'))
          )
        ''');
        await db.execute('''
          CREATE INDEX indice_tarefas_data_ordem
          ON tarefas (data_civil, horario_minutos, identificador)
        ''');
        if (versao >= 3) {
          await db.execute(
            'ALTER TABLE tarefas ADD COLUMN lembrete_ativo INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE tarefas ADD COLUMN lembrete_antecedencia_minutos INTEGER NOT NULL DEFAULT 15',
          );
        }
        if (versao >= 4) {
          await db.execute(
            'ALTER TABLE tarefas ADD COLUMN lembrete_adiado_ms INTEGER',
          );
        }
        if (versao >= 2) {
          await db.execute('''
            CREATE TABLE sessao_foco (
              identificador INTEGER PRIMARY KEY CHECK (identificador = 1),
              tarefa_identificador INTEGER NOT NULL UNIQUE,
              inicio_microssegundos INTEGER,
              FOREIGN KEY (tarefa_identificador)
                REFERENCES tarefas (identificador)
                ON DELETE CASCADE
            )
          ''');
        }
      },
    ),
  );
  await banco.insert('tarefas', {
    'identificador': 1,
    'titulo': 'Tarefa da v$versao',
    'descricao': 'Preservar',
    'data_civil': '2026-11-08',
    'horario_minutos': 9 * 60 + 30,
    'duracao_estimada_microssegundos': const Duration(
      minutes: 45,
    ).inMicroseconds,
    'tempo_registrado_microssegundos': const Duration(
      minutes: 3,
    ).inMicroseconds,
    'prioridade': 'alta',
    'categoria': 'Legado',
    'situacao': 'pendente',
    if (versao >= 3) ...{
      'lembrete_ativo': 1,
      'lembrete_antecedencia_minutos': 30,
    },
    if (versao >= 4)
      'lembrete_adiado_ms': DateTime(2026, 11, 8, 9).millisecondsSinceEpoch,
  });
  if (versao >= 2) {
    await banco.insert('sessao_foco', {
      'identificador': 1,
      'tarefa_identificador': 1,
      'inicio_microssegundos': DateTime(2026, 11, 7, 14).microsecondsSinceEpoch,
    });
  }
  await banco.close();
}

void main() {
  setUpAll(sqfliteFfiInit);

  for (final versao in [1, 2, 3, 4]) {
    test('migra base v$versao sem destruir tarefa ou sessão', () async {
      final diretorio = await Directory.systemTemp.createTemp(
        'flow_task_migracao_v$versao',
      );
      final caminho = path.join(diretorio.path, 'legado.db');
      await _criarBancoLegado(caminho, versao);
      final service = BancoService(
        caminhoBanco: caminho,
        fabricaBanco: databaseFactoryFfi,
      );
      try {
        final tarefa = await service.consultarTarefaPorId(1);
        expect(tarefa, isNotNull);
        expect(tarefa!.titulo, 'Tarefa da v$versao');
        expect(tarefa.descricao, 'Preservar');
        expect(tarefa.tempoRegistrado, const Duration(minutes: 3));
        expect(tarefa.lembreteAtivo, versao >= 3);
        expect(
          tarefa.antecedenciaLembrete,
          Duration(minutes: versao >= 3 ? 30 : 15),
        );
        expect(
          tarefa.lembreteAdiadoAte,
          versao >= 4 ? DateTime(2026, 11, 8, 9) : null,
        );
        expect(tarefa.serieIdentificador, isNull);

        final sessao = await service.consultarSessaoFoco();
        if (versao == 1) {
          expect(sessao, isNull);
        } else {
          expect(sessao!.tarefaIdentificador, 1);
          expect(sessao.inicio, DateTime(2026, 11, 7, 14));
        }
      } finally {
        await service.fechar();
        await diretorio.delete(recursive: true);
      }
    });
  }
}
