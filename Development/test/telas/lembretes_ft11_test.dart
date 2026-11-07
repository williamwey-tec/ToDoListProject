import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_list/control/control_tarefa.dart';
import 'package:to_do_list/model/tarefa.dart';
import 'package:to_do_list/services/notificacao_service.dart';
import 'package:to_do_list/telas/tela_notificacoes.dart';
import 'package:to_do_list/telas/tela_tarefa.dart';

class _ControleFormulario implements OperacoesTarefa, OperacoesLembreteTarefa {
  Tarefa? criada;
  Tarefa? editada;
  ResultadoAgendamentoLembrete resultado =
      ResultadoAgendamentoLembrete.agendadoComPossivelAtraso;

  @override
  ResultadoAgendamentoLembrete? get ultimoResultadoAgendamento => resultado;

  Tarefa _persistir(Tarefa tarefa, int id) => Tarefa(
    identificador: id,
    titulo: tarefa.titulo,
    descricao: tarefa.descricao,
    data: tarefa.data,
    horario: tarefa.horario,
    duracaoEstimada: tarefa.duracaoEstimada,
    tempoRegistrado: tarefa.tempoRegistrado,
    prioridade: tarefa.prioridade,
    categoria: tarefa.categoria,
    status: tarefa.status,
    lembreteAtivo: tarefa.lembreteAtivo,
    antecedenciaLembrete: tarefa.antecedenciaLembrete,
  );

  @override
  Future<Tarefa> criarTarefa(Tarefa tarefa) async {
    criada = _persistir(tarefa, 1);
    return criada!;
  }

  @override
  Future<Tarefa> editarTarefa(int identificador, Tarefa dadosEditados) async {
    editada = _persistir(dadosEditados, identificador);
    return editada!;
  }

  @override
  Future<RelatorioSincronizacaoLembretes> sincronizarLembretes() async =>
      const RelatorioSincronizacaoLembretes(
        agendados: 0,
        cancelados: 0,
        falhas: 0,
        statusPermissao: StatusPermissaoNotificacao.permitida,
      );

  @override
  Future<Tarefa> concluirTarefa(int identificador) =>
      throw UnimplementedError();
  @override
  Future<Tarefa?> consultarTarefaPorId(int identificador) async => null;
  @override
  Future<List<Tarefa>> consultarTarefasPorData(DateTime data) async => const [];
  @override
  Future<List<Tarefa>> consultarTarefasPorIntervalo(
    DateTime dataInicial,
    DateTime dataFinal,
  ) async => const [];
  @override
  Future<void> excluirTarefa(int identificador) async {}
  @override
  Future<Tarefa> reabrirTarefa(int identificador) => throw UnimplementedError();
}

class _PermissaoSimulada implements NotificacaoService {
  _PermissaoSimulada({required this.status, required this.statusAoSolicitar});

  StatusPermissaoNotificacao status;
  final StatusPermissaoNotificacao statusAoSolicitar;
  int solicitacoes = 0;

  @override
  Future<StatusPermissaoNotificacao> consultarPermissao() async => status;

  @override
  Future<StatusPermissaoNotificacao> solicitarPermissao() async {
    solicitacoes++;
    return status = statusAoSolicitar;
  }

  @override
  Future<ResultadoAgendamentoLembrete> agendarLembrete(
    Tarefa tarefa, {
    required DateTime agora,
  }) => throw UnimplementedError();
  @override
  Future<void> cancelarLembrete(int tarefaIdentificador) async {}
  @override
  Future<RelatorioSincronizacaoLembretes> sincronizarLembretes(
    List<Tarefa> tarefas, {
    required DateTime agora,
  }) => throw UnimplementedError();
}

Widget _rotaFormulario(Widget tela) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => tela)),
          child: const Text('Abrir'),
        ),
      ),
    ),
  ),
);

Future<void> _abrir(WidgetTester tester, Widget tela) async {
  await tester.pumpWidget(_rotaFormulario(tela));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

void main() {
  final agora = DateTime(2026, 11, 7, 14, 20);

  testWidgets('lembrete é opt-in, inicia em 15 min e passado não bloqueia', (
    tester,
  ) async {
    final controle = _ControleFormulario()
      ..resultado = ResultadoAgendamentoLembrete.horarioPassado;
    await _abrir(
      tester,
      TelaTarefa(
        controleTarefa: controle,
        dataInicial: DateTime(2026, 11, 7),
        relogio: () => agora,
      ),
    );

    final switchLembrete = find.byKey(const Key('ativar_lembrete_individual'));
    await tester.ensureVisible(switchLembrete);
    expect(tester.widget<SwitchListTile>(switchLembrete).value, isFalse);
    await tester.tap(switchLembrete);
    await tester.pumpAndSettle();

    expect(find.text('15 minutos antes'), findsOneWidget);
    expect(
      find.byKey(const Key('aviso_lembrete_nao_agendado')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('campo_titulo')),
      'Lembrete passado',
    );
    final salvar = find.text('Salvar tarefa');
    await tester.ensureVisible(salvar);
    await tester.tap(salvar);
    await tester.pumpAndSettle();

    expect(controle.criada, isNotNull);
    expect(controle.criada!.lembreteAtivo, isTrue);
    expect(controle.criada!.antecedenciaLembrete, const Duration(minutes: 15));
    expect(
      find.textContaining('horário do lembrete já passou'),
      findsOneWidget,
    );
  });

  testWidgets('edição reabre lembrete e permite opção no horário', (
    tester,
  ) async {
    final controle = _ControleFormulario();
    final original = Tarefa(
      identificador: 9,
      titulo: 'Original',
      descricao: 'Não perder',
      data: DateTime(2026, 11, 9),
      horario: HorarioTarefa(hora: 9, minuto: 0),
      duracaoEstimada: const Duration(minutes: 30),
      lembreteAtivo: true,
      antecedenciaLembrete: const Duration(minutes: 30),
    );
    await _abrir(
      tester,
      TelaTarefa(
        controleTarefa: controle,
        tarefa: original,
        relogio: () => agora,
      ),
    );

    final switchLembrete = find.byKey(const Key('ativar_lembrete_individual'));
    await tester.ensureVisible(switchLembrete);
    expect(tester.widget<SwitchListTile>(switchLembrete).value, isTrue);
    expect(find.text('30 minutos antes'), findsOneWidget);

    final antecedencia = find.byKey(const Key('antecedencia_lembrete'));
    await tester.tap(antecedencia);
    await tester.pumpAndSettle();
    await tester.tap(find.text('No horário').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_titulo')), 'Editada');
    final salvar = find.text('Salvar alterações');
    await tester.ensureVisible(salvar);
    await tester.tap(salvar);
    await tester.pumpAndSettle();

    expect(controle.editada!.lembreteAtivo, isTrue);
    expect(controle.editada!.antecedenciaLembrete, Duration.zero);
    expect(controle.editada!.descricao, 'Não perder');
  });

  testWidgets('permissão recusada mantém tela e funções disponíveis', (
    tester,
  ) async {
    final servico = _PermissaoSimulada(
      status: StatusPermissaoNotificacao.negada,
      statusAoSolicitar: StatusPermissaoNotificacao.negada,
    );
    await tester.pumpWidget(
      MaterialApp(home: TelaNotificacoes(notificacaoService: servico)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notificações não permitidas'), findsOneWidget);

    await tester.tap(find.byKey(const Key('solicitar_permissao_notificacao')));
    await tester.pumpAndSettle();

    expect(servico.solicitacoes, 1);
    expect(find.text('Notificações não permitidas'), findsOneWidget);
    expect(
      find.textContaining('demais funções continuam disponíveis'),
      findsOneWidget,
    );
  });

  testWidgets('não anuncia sincronização quando ela falha', (tester) async {
    final servico = _PermissaoSimulada(
      status: StatusPermissaoNotificacao.negada,
      statusAoSolicitar: StatusPermissaoNotificacao.permitida,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TelaNotificacoes(
          notificacaoService: servico,
          sincronizarLembretes: () async =>
              const RelatorioSincronizacaoLembretes(
                agendados: 0,
                cancelados: 0,
                falhas: 1,
                statusPermissao: StatusPermissaoNotificacao.erro,
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('solicitar_permissao_notificacao')));
    await tester.pumpAndSettle();

    expect(find.text('Notificações permitidas'), findsOneWidget);
    expect(find.textContaining('não foram sincronizados'), findsOneWidget);
    expect(
      find.text(
        'Notificações permitidas. Lembretes futuros foram sincronizados.',
      ),
      findsNothing,
    );
  });
}
