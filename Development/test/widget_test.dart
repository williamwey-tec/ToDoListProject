import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_list/control/control_tarefa.dart';
import 'package:to_do_list/main.dart';
import 'package:to_do_list/model/tarefa.dart';

class _ConsultasVazias implements OperacoesTarefa {
  @override
  Future<List<Tarefa>> consultarTarefasPorData(DateTime data) async => [];

  @override
  Future<List<Tarefa>> consultarTarefasPorIntervalo(
    DateTime inicio,
    DateTime fim,
  ) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('FlowTask abre Hoje e navega até o Perfil', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MyApp(
        controleTarefa: _ConsultasVazias(),
        relogio: () => DateTime(2026, 11, 7, 9),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bom dia!'), findsOneWidget);
    expect(find.text('Nenhuma tarefa para hoje.'), findsOneWidget);

    final navegacao = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: navegacao, matching: find.text('Perfil')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Seu perfil'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
