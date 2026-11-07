import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:to_do_list/control/control_foco.dart';
import 'package:to_do_list/control/control_tarefa.dart';
import 'package:to_do_list/model/aviso_agenda.dart';
import 'package:to_do_list/model/preferencias_notificacoes.dart';
import 'package:to_do_list/model/tarefa.dart';
import 'package:to_do_list/services/banco_service.dart';
import 'package:to_do_list/services/configuracoes_service.dart';
import 'package:to_do_list/services/notificacao_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  final agora = DateTime(2026, 11, 7, 7);
  DateTime dia(int dia) => DateTime(2026, 11, dia);

  Tarefa tarefa(
    String titulo,
    DateTime data, {
    int hora = 9,
    RepeticaoTarefa repeticao = RepeticaoTarefa.nenhuma,
  }) => Tarefa(
    titulo: titulo,
    data: data,
    horario: HorarioTarefa(hora: hora, minuto: 0),
    duracaoEstimada: const Duration(minutes: 20),
    repeticao: repeticao,
  );

  test('preferências do resumo e dos canais sobrevivem à reabertura', () async {
    SharedPreferences.setMockInitialValues({});
    final configuracoes = ConfiguracoesService();
    addTearDown(configuracoes.dispose);
    await configuracoes.salvarNomeExibicao('Marina');
    await configuracoes.salvarNotificacoes(
      const PreferenciasNotificacoes(
        resumo: true,
        minutosResumo: 485,
        blocos: true,
        som: false,
        vibracao: false,
      ),
    );

    final reaberto = ConfiguracoesService();
    addTearDown(reaberto.dispose);
    await reaberto.carregar();
    expect(reaberto.configuracoes.nomeExibicao, 'Marina');
    expect(reaberto.configuracoes.notificacoes.paraMapa(), {
      'resumo': true,
      'minutosResumo': 485,
      'blocos': true,
      'individuais': true,
      'som': false,
      'vibracao': false,
    });
  });

  test('resumo e blocos ignoram concluídas e delimitam os horários', () {
    final itens = [
      for (final (id, hora) in [(1, 11), (2, 12), (3, 18), (4, 20)])
        Tarefa(
          identificador: id,
          titulo: 'Tarefa $id',
          data: dia(7),
          horario: HorarioTarefa(hora: hora, minuto: 0),
          status: id == 4 ? StatusTarefa.concluida : StatusTarefa.pendente,
        ),
    ];
    final avisos = AvisoAgenda.planejar(
      itens,
      const PreferenciasNotificacoes(resumo: true, blocos: true),
      agora,
    );
    expect(avisos.map((aviso) => aviso.horario.hour), [7, 8, 12, 18]);
    expect(avisos.map((aviso) => aviso.tarefas.map((t) => t.identificador)), [
      [1, 2, 3],
      [1],
      [2],
      [3],
    ]);
    expect(avisos.map((a) => a.id).toSet(), hasLength(4));
    final resposta = RespostaLembrete.interpretar(
      'agenda:2|assinatura',
      'adiar',
    );
    expect(resposta?.tarefaId, 2);
    expect(resposta?.acao, AcaoNotificacao.adiar);
    expect(RespostaLembrete.interpretar('agenda:-2', 'concluir'), isNull);
  });

  group('SQLite', () {
    late BancoService banco;
    late ControlTarefa controle;

    setUp(() {
      banco = BancoService(
        caminhoBanco: inMemoryDatabasePath,
        fabricaBanco: databaseFactoryFfi,
      );
      controle = ControlTarefa(banco: banco, relogio: () => agora);
    });

    tearDown(() => banco.fechar());

    test(
      'séries diária e semanal geram ocorrências independentes sem duplicar',
      () async {
        final primeira = await controle.criarTarefa(
          tarefa('Diária', dia(7), repeticao: RepeticaoTarefa.diaria),
        );
        final semanal = await controle.criarTarefa(
          tarefa('Semanal', dia(7), repeticao: RepeticaoTarefa.semanal),
        );
        final foco = ControlFoco(banco: banco, relogio: () => agora);
        await foco.selecionarTarefa(primeira.identificador!);
        await foco.iniciar();
        await banco.concluirTarefaComFoco(
          primeira.identificador!,
          agora.add(const Duration(minutes: 8)),
        );

        final amanha = (await controle.consultarTarefasPorData(dia(8))).single;
        expect(amanha.status, StatusTarefa.pendente);
        expect(amanha.tempoRegistrado, Duration.zero);
        expect(amanha.serieIdentificador, primeira.serieIdentificador);
        expect(
          (await banco.consultarTarefaPorId(
            primeira.identificador!,
          ))?.tempoRegistrado,
          const Duration(minutes: 8),
        );
        final naSemana = await controle.consultarTarefasPorData(dia(14));
        expect(
          naSemana.map((t) => t.serieIdentificador),
          containsAll([
            primeira.serieIdentificador,
            semanal.serieIdentificador,
          ]),
        );
        expect(await controle.consultarTarefasPorData(dia(14)), hasLength(2));
      },
    );

    test(
      'alterar e excluir respeitam o alcance, inclusive após expandir a série',
      () async {
        await controle.criarTarefa(
          tarefa('Original', dia(7), repeticao: RepeticaoTarefa.diaria),
        );
        final segunda = (await controle.consultarTarefasPorData(dia(8))).single;
        final terceira = (await controle.consultarTarefasPorData(
          dia(9),
        )).single;
        final quarta = (await controle.consultarTarefasPorData(dia(10))).single;

        await controle.editarOcorrencia(
          segunda.identificador!,
          tarefa('Só esta', dia(8)),
          AlcanceRecorrencia.somenteEsta,
        );
        expect(
          (await controle.consultarTarefasPorData(dia(9))).single.titulo,
          'Original',
        );

        await controle.excluirOcorrencia(
          terceira.identificador!,
          AlcanceRecorrencia.somenteEsta,
        );
        await controle.editarOcorrencia(
          quarta.identificador!,
          tarefa('Em diante', dia(10), repeticao: RepeticaoTarefa.diaria),
          AlcanceRecorrencia.estaEProximas,
        );
        expect(await controle.consultarTarefasPorData(dia(9)), isEmpty);
        expect(
          (await controle.consultarTarefasPorData(dia(8))).single.titulo,
          'Só esta',
        );
        expect(
          (await controle.consultarTarefasPorData(dia(11))).single.titulo,
          'Em diante',
        );

        await controle.excluirOcorrencia(
          quarta.identificador!,
          AlcanceRecorrencia.estaEProximas,
        );
        expect(await controle.consultarTarefasPorData(dia(30)), isEmpty);
        expect(await controle.consultarTarefasPorData(dia(10)), isEmpty);
        expect(await controle.consultarTarefasPorData(dia(7)), hasLength(1));
      },
    );

    test(
      'adiar não altera o horário da tarefa e concluir apaga o adiamento',
      () async {
        final criada = await controle.criarTarefa(tarefa('Adiar', dia(7)));
        final id = criada.identificador!;
        await controle.adiarLembrete(id);
        final adiada = (await banco.consultarTarefaPorId(id))!;
        expect(
          adiada.lembreteAdiadoAte,
          agora.add(const Duration(minutes: 15)),
        );
        expect(adiada.horario?.hora, 9);
        await controle.concluirTarefa(id);
        expect(
          (await banco.consultarTarefaPorId(id))?.lembreteAdiadoAte,
          isNull,
        );
        expect(await controle.adiarLembrete(id), isNull);
      },
    );
  });
}
