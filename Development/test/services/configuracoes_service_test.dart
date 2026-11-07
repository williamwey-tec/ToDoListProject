import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_list/services/configuracoes_service.dart';

class _ArmazenamentoMemoria implements ArmazenamentoConfiguracoes {
  _ArmazenamentoMemoria([this.nome]);

  String? nome;
  int leituras = 0;
  bool falharGravacao = false;
  Completer<String?>? leituraPendente;

  @override
  Future<String?> lerNomeExibicao() async {
    leituras++;
    final pendente = leituraPendente;
    if (pendente != null) return pendente.future;
    return nome;
  }

  @override
  Future<void> salvarNomeExibicao(String? nomeExibicao) async {
    if (falharGravacao) throw StateError('falha simulada');
    nome = nomeExibicao;
  }
}

void main() {
  test('normaliza, persiste, reabre e remove o nome local', () async {
    final armazenamento = _ArmazenamentoMemoria();
    final configuracoes = ConfiguracoesService(armazenamento: armazenamento);

    await configuracoes.carregar();
    await configuracoes.carregar();
    expect(armazenamento.leituras, 1);

    await configuracoes.salvarNomeExibicao('  Marina  ');
    expect(configuracoes.configuracoes.nomeExibicao, 'Marina');
    expect(armazenamento.nome, 'Marina');

    final reaberto = ConfiguracoesService(armazenamento: armazenamento);
    await reaberto.carregar();
    expect(reaberto.configuracoes.nomeExibicao, 'Marina');

    await reaberto.salvarNomeExibicao('   ');
    expect(reaberto.configuracoes.nomeExibicao, isNull);
    expect(armazenamento.nome, isNull);

    final reabertoSemNome = ConfiguracoesService(armazenamento: armazenamento);
    await reabertoSemNome.carregar();
    expect(reabertoSemNome.configuracoes.nomeExibicao, isNull);
  });

  test('falha de persistência preserva o último estado confirmado', () async {
    final armazenamento = _ArmazenamentoMemoria('Nome anterior');
    final configuracoes = ConfiguracoesService(armazenamento: armazenamento);
    await configuracoes.carregar();
    armazenamento.falharGravacao = true;

    await expectLater(
      configuracoes.salvarNomeExibicao('Novo nome'),
      throwsStateError,
    );

    expect(configuracoes.configuracoes.nomeExibicao, 'Nome anterior');
    expect(armazenamento.nome, 'Nome anterior');
  });

  test(
    'primeiro salvamento espera a leitura inicial e não é sobrescrito',
    () async {
      final leitura = Completer<String?>();
      final armazenamento = _ArmazenamentoMemoria('Nome antigo')
        ..leituraPendente = leitura;
      final configuracoes = ConfiguracoesService(armazenamento: armazenamento);

      final carregamento = configuracoes.carregar();
      final salvamento = configuracoes.salvarNomeExibicao('Nome novo');
      leitura.complete('Nome antigo');
      await carregamento;
      await salvamento;

      expect(configuracoes.configuracoes.nomeExibicao, 'Nome novo');
      expect(armazenamento.nome, 'Nome novo');
      expect(armazenamento.leituras, 1);
    },
  );
}
