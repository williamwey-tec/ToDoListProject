import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_list/control/control_tarefa.dart';
import 'package:to_do_list/main.dart';
import 'package:to_do_list/model/tarefa.dart';
import 'package:to_do_list/services/configuracoes_service.dart';

class _ArmazenamentoMemoria implements ArmazenamentoConfiguracoes {
  _ArmazenamentoMemoria([this.nome]);

  String? nome;
  bool falharGravacao = false;

  @override
  Future<String?> lerNomeExibicao() async => nome;

  @override
  Future<void> salvarNomeExibicao(String? nomeExibicao) async {
    if (falharGravacao) throw StateError('falha simulada');
    nome = nomeExibicao;
  }
}

class _ControleTarefaVazio implements OperacoesTarefa {
  @override
  Future<Tarefa> criarTarefa(Tarefa tarefa) => throw UnimplementedError();

  @override
  Future<Tarefa> editarTarefa(int identificador, Tarefa dadosEditados) =>
      throw UnimplementedError();

  @override
  Future<Tarefa> concluirTarefa(int identificador) =>
      throw UnimplementedError();

  @override
  Future<Tarefa> reabrirTarefa(int identificador) => throw UnimplementedError();

  @override
  Future<void> excluirTarefa(int identificador) => throw UnimplementedError();

  @override
  Future<Tarefa?> consultarTarefaPorId(int identificador) async => null;

  @override
  Future<List<Tarefa>> consultarTarefasPorData(DateTime data) async => const [];

  @override
  Future<List<Tarefa>> consultarTarefasPorIntervalo(
    DateTime dataInicial,
    DateTime dataFinal,
  ) async => const [];
}

DateTime _agora() => DateTime(2026, 11, 7, 14, 20);

Widget _app(ConfiguracoesService configuracoes, {Key? key}) => MyApp(
  key: key,
  controleTarefa: _ControleTarefaVazio(),
  configuracoesService: configuracoes,
  relogio: _agora,
);

Future<void> _abrirPerfil(WidgetTester tester) async {
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
}

Future<void> _abrirHoje(WidgetTester tester) async {
  await tester.tap(find.text('Hoje'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('salva com trim, atualiza a saudação e persiste ao reabrir', (
    tester,
  ) async {
    final armazenamento = _ArmazenamentoMemoria();
    final configuracoes = ConfiguracoesService(armazenamento: armazenamento);

    await tester.pumpWidget(_app(configuracoes));
    await tester.pumpAndSettle();
    await _abrirPerfil(tester);

    await tester.enterText(
      find.byKey(const Key('campo_nome_exibicao')),
      '  Marina  ',
    );
    await tester.tap(find.byKey(const Key('salvar_perfil')));
    await tester.pumpAndSettle();

    expect(armazenamento.nome, 'Marina');
    expect(find.text('Perfil salvo.'), findsOneWidget);
    await _abrirHoje(tester);
    expect(find.text('Boa tarde, Marina!'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final reaberto = ConfiguracoesService(armazenamento: armazenamento);
    await tester.pumpWidget(
      _app(reaberto, key: const ValueKey('aplicativo_reaberto')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Boa tarde, Marina!'), findsOneWidget);
  });

  testWidgets('remover nome restaura a saudação genérica', (tester) async {
    final armazenamento = _ArmazenamentoMemoria('Marina');
    final configuracoes = ConfiguracoesService(armazenamento: armazenamento);

    await tester.pumpWidget(_app(configuracoes));
    await tester.pumpAndSettle();
    expect(find.text('Boa tarde, Marina!'), findsOneWidget);
    await _abrirPerfil(tester);

    await tester.tap(find.byKey(const Key('remover_nome')));
    await tester.pumpAndSettle();

    expect(armazenamento.nome, isNull);
    expect(find.text('Nome removido.'), findsOneWidget);
    await _abrirHoje(tester);
    expect(find.text('Boa tarde!'), findsOneWidget);
    expect(find.text('Boa tarde, Marina!'), findsNothing);
  });

  testWidgets('perfil abre a tela de Notificações existente', (tester) async {
    final configuracoes = ConfiguracoesService(
      armazenamento: _ArmazenamentoMemoria(),
    );
    await tester.pumpWidget(_app(configuracoes));
    await tester.pumpAndSettle();
    await _abrirPerfil(tester);

    final acesso = find.byKey(const Key('abrir_notificacoes_perfil'));
    await tester.ensureVisible(acesso);
    await tester.tap(acesso);
    await tester.pumpAndSettle();

    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('Lembretes no seu ritmo'), findsOneWidget);
  });

  testWidgets('falha ao salvar não altera o nome confirmado nem a saudação', (
    tester,
  ) async {
    final armazenamento = _ArmazenamentoMemoria('Lia');
    final configuracoes = ConfiguracoesService(armazenamento: armazenamento);
    await tester.pumpWidget(_app(configuracoes));
    await tester.pumpAndSettle();
    await _abrirPerfil(tester);

    armazenamento.falharGravacao = true;
    await tester.enterText(
      find.byKey(const Key('campo_nome_exibicao')),
      'Outro nome',
    );
    await tester.tap(find.byKey(const Key('salvar_perfil')));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível salvar o perfil. Tente novamente.'),
      findsOneWidget,
    );
    expect(configuracoes.configuracoes.nomeExibicao, 'Lia');
    expect(armazenamento.nome, 'Lia');
    await _abrirHoje(tester);
    expect(find.text('Boa tarde, Lia!'), findsOneWidget);
    expect(find.text('Boa tarde, Outro nome!'), findsNothing);
  });
}
