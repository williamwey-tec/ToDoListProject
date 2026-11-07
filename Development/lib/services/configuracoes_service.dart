import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/configuracoes.dart';

/// Contrato pequeno para permitir validar a persistência sem acessar a
/// plataforma nos testes.
abstract interface class ArmazenamentoConfiguracoes {
  Future<String?> lerNomeExibicao();

  Future<void> salvarNomeExibicao(String? nomeExibicao);
}

class ArmazenamentoPreferencias implements ArmazenamentoConfiguracoes {
  static const _chaveNomeExibicao = 'perfil.nome_exibicao';

  @override
  Future<String?> lerNomeExibicao() async {
    final preferencias = await SharedPreferences.getInstance();
    return preferencias.getString(_chaveNomeExibicao);
  }

  @override
  Future<void> salvarNomeExibicao(String? nomeExibicao) async {
    final preferencias = await SharedPreferences.getInstance();
    final persistiu = nomeExibicao == null
        ? await preferencias.remove(_chaveNomeExibicao)
        : await preferencias.setString(_chaveNomeExibicao, nomeExibicao);
    if (!persistiu) {
      throw StateError('Não foi possível persistir o nome de exibição.');
    }
  }
}

/// Fonte compartilhada das preferências em memória.
///
/// O armazenamento é consultado apenas na inicialização. Ao salvar, o estado
/// visível só muda depois que a gravação local termina com sucesso.
class ConfiguracoesService extends ChangeNotifier {
  ConfiguracoesService({ArmazenamentoConfiguracoes? armazenamento})
    : _armazenamento = armazenamento ?? ArmazenamentoPreferencias();

  final ArmazenamentoConfiguracoes _armazenamento;
  Configuracoes _configuracoes = const Configuracoes();
  Future<void>? _carregamento;
  bool _ativo = true;

  Configuracoes get configuracoes => _configuracoes;

  Future<void> carregar() => _carregamento ??= _carregarUmaVez();

  Future<void> _carregarUmaVez() async {
    try {
      final nome = await _armazenamento.lerNomeExibicao();
      _configuracoes = Configuracoes(
        nomeExibicao: Configuracoes.normalizarNomeExibicao(nome),
      );
    } catch (_) {
      _configuracoes = const Configuracoes();
    } finally {
      if (_ativo) notifyListeners();
    }
  }

  Future<void> salvarNomeExibicao(String? valor) async {
    await carregar();
    final nomeNormalizado = Configuracoes.normalizarNomeExibicao(valor);
    await _armazenamento.salvarNomeExibicao(nomeNormalizado);

    _configuracoes = _configuracoes.copiarComNomeExibicao(nomeNormalizado);
    if (_ativo) notifyListeners();
  }

  @override
  void dispose() {
    _ativo = false;
    super.dispose();
  }
}
