import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_list/widgets/botao.dart';
import 'package:to_do_list/widgets/campo_texto.dart';

void main() {
  testWidgets('botão carregando fica realmente indisponível', (tester) async {
    var acionamentos = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Botao(
            texto: 'Salvar',
            carregando: true,
            onPressed: () => acionamentos++,
          ),
        ),
      ),
    );

    final botao = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(botao.onPressed, isNull);
    await tester.tap(find.byType(ElevatedButton));
    expect(acionamentos, 0);
  });

  testWidgets('rótulo permanece dentro da borda do campo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CampoTexto(rotulo: 'Título', valorInicial: 'Conteúdo'),
        ),
      ),
    );

    final rotulo = tester.getRect(find.text('Título'));
    final campo = tester.getRect(find.byType(TextFormField));
    expect(rotulo.top, greaterThan(campo.top));
    expect(rotulo.bottom, lessThan(campo.bottom));
  });
}
