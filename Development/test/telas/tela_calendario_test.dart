import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_list/telas/tela_calendario.dart';
import 'package:to_do_list/widgets/card_tarefa.dart';

void main() {
  testWidgets('seleciona datas e alterna conclusão com o modelo comum', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TelaCalendario())),
    );

    expect(find.text('Quinta, 8 de outubro'), findsOneWidget);
    expect(
      find.text('3 concluídas · 2 pendentes · 1 pausada · 1 atrasada'),
      findsOneWidget,
    );

    final cardRelatorio = find.ancestor(
      of: find.text('Enviar relatório'),
      matching: find.byType(CardTarefa),
    );
    final alternarRelatorio = find.descendant(
      of: cardRelatorio,
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(alternarRelatorio);
    await tester.tap(alternarRelatorio);
    await tester.pumpAndSettle();

    expect(find.text('4 concluídas · 2 pendentes · 1 pausada'), findsOneWidget);
    expect(find.text('55 min realizados'), findsOneWidget);

    await tester.ensureVisible(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    expect(find.text('Segunda, 5 de outubro'), findsOneWidget);
    expect(find.text('2 tarefas'), findsOneWidget);
  });
}
