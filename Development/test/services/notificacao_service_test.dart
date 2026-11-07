import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:to_do_list/control/control_foco.dart';
import 'package:to_do_list/control/control_tarefa.dart';
import 'package:to_do_list/model/tarefa.dart';
import 'package:to_do_list/services/banco_service.dart';
import 'package:to_do_list/services/notificacao_service.dart';

class _NotificacoesSimuladas implements NotificacaoService {
  StatusPermissaoNotificacao permissao = StatusPermissaoNotificacao.permitida;
  bool falharAgendamento = false;
  final Map<int, Tarefa> agendadas = {};
  final List<int> canceladas = [];
  Completer<void>? sincronizacaoIniciada;
  Completer<void>? liberarSincronizacao;

  @override
  Future<StatusPermissaoNotificacao> consultarPermissao() async => permissao;

  @override
  Future<StatusPermissaoNotificacao> solicitarPermissao() async => permissao;

  @override
  Future<ResultadoAgendamentoLembrete> agendarLembrete(
    Tarefa tarefa, {
    required DateTime agora,
  }) async {
    final id = tarefa.identificador!;
    final resultado = _resultado(tarefa, agora);
    if (resultado == ResultadoAgendamentoLembrete.agendadoComPossivelAtraso) {
      agendadas[id] = tarefa;
    } else {
      agendadas.remove(id);
      canceladas.add(id);
    }
    return resultado;
  }

  @override
  Future<void> cancelarLembrete(int tarefaIdentificador) async {
    agendadas.remove(tarefaIdentificador);
    canceladas.add(tarefaIdentificador);
  }

  @override
  Future<RelatorioSincronizacaoLembretes> sincronizarLembretes(
    List<Tarefa> tarefas, {
    required DateTime agora,
  }) async {
    sincronizacaoIniciada?.complete();
    await liberarSincronizacao?.future;
    final idsPersistidos = tarefas
        .map((tarefa) => tarefa.identificador!)
        .toSet();
    agendadas.removeWhere((id, _) => !idsPersistidos.contains(id));
    var agendamentos = 0;
    var falhas = 0;
    for (final tarefa in tarefas) {
      final resultado = await agendarLembrete(tarefa, agora: agora);
      if (resultado == ResultadoAgendamentoLembrete.agendadoComPossivelAtraso) {
        agendamentos++;
      } else if (resultado == ResultadoAgendamentoLembrete.falha) {
        falhas++;
      }
    }
    return RelatorioSincronizacaoLembretes(
      agendados: agendamentos,
      cancelados: canceladas.length,
      falhas: falhas,
      statusPermissao: permissao,
    );
  }

  ResultadoAgendamentoLembrete _resultado(Tarefa tarefa, DateTime agora) {
    if (!tarefa.lembreteAtivo) {
      return ResultadoAgendamentoLembrete.desativado;
    }
    if (tarefa.status == StatusTarefa.concluida) {
      return ResultadoAgendamentoLembrete.tarefaConcluida;
    }
    final horario = tarefa.horario;
    if (horario == null) {
      return ResultadoAgendamentoLembrete.horarioAusente;
    }
    final instante = DateTime(
      tarefa.data.year,
      tarefa.data.month,
      tarefa.data.day,
      horario.hora,
      horario.minuto,
    ).subtract(tarefa.antecedenciaLembrete);
    if (!instante.isAfter(agora)) {
      return ResultadoAgendamentoLembrete.horarioPassado;
    }
    if (permissao == StatusPermissaoNotificacao.negada) {
      return ResultadoAgendamentoLembrete.permissaoNegada;
    }
    if (permissao != StatusPermissaoNotificacao.permitida) {
      return ResultadoAgendamentoLembrete.indisponivel;
    }
    if (falharAgendamento) return ResultadoAgendamentoLembrete.falha;
    return ResultadoAgendamentoLembrete.agendadoComPossivelAtraso;
  }
}

Tarefa _tarefa(
  String titulo, {
  DateTime? data,
  HorarioTarefa? horario,
  bool lembreteAtivo = true,
  Duration antecedencia = const Duration(minutes: 15),
}) => Tarefa(
  titulo: titulo,
  data: data ?? DateTime(2026, 11, 8),
  horario: horario ?? HorarioTarefa(hora: 10, minuto: 0),
  duracaoEstimada: const Duration(minutes: 30),
  lembreteAtivo: lembreteAtivo,
  antecedenciaLembrete: antecedencia,
);

void main() {
  late Directory diretorio;
  late BancoService banco;
  late _NotificacoesSimuladas notificacoes;
  late CoordenadorLembretes coordenador;
  late ControlTarefa tarefas;
  var agora = DateTime(2026, 11, 7, 14, 20);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    agora = DateTime(2026, 11, 7, 14, 20);
    diretorio = await Directory.systemTemp.createTemp('flow_task_ft11_');
    banco = BancoService(
      caminhoBanco: path.join(diretorio.path, 'teste.db'),
      fabricaBanco: databaseFactoryFfi,
    );
    notificacoes = _NotificacoesSimuladas();
    coordenador = CoordenadorLembretes(
      banco: banco,
      notificacaoService: notificacoes,
      relogio: () => agora,
    );
    tarefas = ControlTarefa(
      banco: banco,
      relogio: () => agora,
      coordenadorLembretes: coordenador,
    );
  });

  tearDown(() async {
    await banco.fechar();
    await diretorio.delete(recursive: true);
  });

  test('cria, edita e remove um único agendamento pelo ID da tarefa', () async {
    final criada = await tarefas.criarTarefa(_tarefa('Original'));
    final id = criada.identificador!;

    expect(notificacoes.agendadas.keys, [id]);
    expect(
      tarefas.ultimoResultadoAgendamento,
      ResultadoAgendamentoLembrete.agendadoComPossivelAtraso,
    );

    await tarefas.editarTarefa(
      id,
      _tarefa(
        'Editada',
        horario: HorarioTarefa(hora: 11, minuto: 30),
        antecedencia: const Duration(minutes: 30),
      ),
    );
    expect(notificacoes.agendadas, hasLength(1));
    expect(notificacoes.agendadas[id]!.titulo, 'Editada');
    expect(
      notificacoes.agendadas[id]!.antecedenciaLembrete,
      const Duration(minutes: 30),
    );

    await tarefas.editarTarefa(
      id,
      _tarefa('Sem lembrete', lembreteAtivo: false),
    );
    expect(notificacoes.agendadas, isEmpty);
    expect(notificacoes.canceladas, contains(id));
  });

  test('recusa e falha não impedem persistir a tarefa', () async {
    notificacoes.permissao = StatusPermissaoNotificacao.negada;
    final negada = await tarefas.criarTarefa(_tarefa('Permissão negada'));
    expect(negada.identificador, isNotNull);
    expect(
      tarefas.ultimoResultadoAgendamento,
      ResultadoAgendamentoLembrete.permissaoNegada,
    );

    notificacoes.permissao = StatusPermissaoNotificacao.permitida;
    notificacoes.falharAgendamento = true;
    final falhou = await tarefas.criarTarefa(_tarefa('Plugin falhou'));
    expect(falhou.identificador, isNotNull);
    expect(
      tarefas.ultimoResultadoAgendamento,
      ResultadoAgendamentoLembrete.falha,
    );
    expect(await banco.consultarTodasTarefas(), hasLength(2));
  });

  test(
    'sincroniza após permissão sem recriar concluídas ou passadas',
    () async {
      notificacoes.permissao = StatusPermissaoNotificacao.negada;
      final futura = await tarefas.criarTarefa(_tarefa('Futura'));
      final concluida = await tarefas.criarTarefa(_tarefa('Concluída'));
      await tarefas.concluirTarefa(concluida.identificador!);
      await tarefas.criarTarefa(
        _tarefa(
          'Passada',
          data: DateTime(2026, 11, 7),
          horario: HorarioTarefa(hora: 13, minuto: 0),
        ),
      );

      notificacoes.permissao = StatusPermissaoNotificacao.permitida;
      final relatorio = await tarefas.sincronizarLembretes();

      expect(relatorio.falhas, 0);
      expect(notificacoes.agendadas.keys, [futura.identificador]);
    },
  );

  test('conclusão pelo Foco mantém transação e cancela o lembrete', () async {
    final tarefa = await tarefas.criarTarefa(_tarefa('Foco'));
    final foco = ControlFoco(
      banco: banco,
      relogio: () => agora,
      coordenadorLembretes: coordenador,
    );
    await foco.selecionarTarefa(tarefa.identificador!);
    await foco.iniciar();
    agora = agora.add(const Duration(minutes: 7));

    await foco.concluirTarefa();

    final persistida = await banco.consultarTarefaPorId(tarefa.identificador!);
    expect(persistida!.status, StatusTarefa.concluida);
    expect(persistida.tempoRegistrado, const Duration(minutes: 7));
    expect(await banco.consultarSessaoFoco(), isNull);
    expect(notificacoes.agendadas, isEmpty);
  });

  test(
    'fila impede sincronização antiga de restaurar lembrete removido',
    () async {
      final tarefa = await tarefas.criarTarefa(_tarefa('Corrida'));
      notificacoes.sincronizacaoIniciada = Completer<void>();
      notificacoes.liberarSincronizacao = Completer<void>();

      final sincronizando = tarefas.sincronizarLembretes();
      await notificacoes.sincronizacaoIniciada!.future;
      final editando = tarefas.editarTarefa(
        tarefa.identificador!,
        _tarefa('Corrida', lembreteAtivo: false),
      );
      await Future<void>.delayed(Duration.zero);
      notificacoes.liberarSincronizacao!.complete();
      await Future.wait([sincronizando, editando]);

      expect(notificacoes.agendadas, isEmpty);
      final persistida = await banco.consultarTarefaPorId(
        tarefa.identificador!,
      );
      expect(persistida!.lembreteAtivo, isFalse);
    },
  );
}
