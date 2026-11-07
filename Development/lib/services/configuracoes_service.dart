import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/configuracoes.dart';
import '../model/preferencias_notificacoes.dart';

/// Contrato pequeno para permitir validar a persistência sem acessar a
/// plataforma nos testes.
abstract interface class ArmazenamentoConfiguracoes {
  Future<String?> lerNomeExibicao();

  Future<void> salvarNomeExibicao(String? nomeExibicao);
}

abstract interface class ArmazenamentoNotificacoes {
  Future<PreferenciasNotificacoes> lerNotificacoes();
  Future<void> salvarNotificacoes(PreferenciasNotificacoes valor);
}

class ArmazenamentoPreferencias
    implements ArmazenamentoConfiguracoes, ArmazenamentoNotificacoes {
  static const _chaveNotificacoes = 'notificacoes.preferencias';

  @override
  Future<PreferenciasNotificacoes> lerNotificacoes() async {
    final preferencias = await SharedPreferences.getInstance();
    final json = preferencias.getString(_chaveNotificacoes);
    if (json == null) return const PreferenciasNotificacoes();
    return PreferenciasNotificacoes.doMapa(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> salvarNotificacoes(PreferenciasNotificacoes valor) async {
    final preferencias = await SharedPreferences.getInstance();
    if (!await preferencias.setString(
      _chaveNotificacoes,
      jsonEncode(valor.paraMapa()),
    )) {
      throw StateError('Não foi possível salvar as notificações.');
    }
  }

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

  ArmazenamentoNotificacoes? get _armazenamentoNotificacoes {
    final armazenamento = _armazenamento;
    return armazenamento is ArmazenamentoNotificacoes
        ? armazenamento as ArmazenamentoNotificacoes
        : null;
  }

  Future<void> _carregarUmaVez() async {
    try {
      final nome = await _armazenamento.lerNomeExibicao();
      _configuracoes = Configuracoes(
        nomeExibicao: Configuracoes.normalizarNomeExibicao(nome),
      );
    } catch (_) {
      _configuracoes = const Configuracoes();
    }
    try {
      final notificacoes = await _armazenamentoNotificacoes?.lerNotificacoes();
      if (notificacoes != null) {
        _configuracoes = _configuracoes.copiarComNotificacoes(notificacoes);
      }
    } catch (_) {
      // Uma preferência inválida não impede carregar o perfil.
    }
    if (_ativo) notifyListeners();
  }

  Future<void> salvarNomeExibicao(String? valor) async {
    await carregar();
    final nomeNormalizado = Configuracoes.normalizarNomeExibicao(valor);
    await _armazenamento.salvarNomeExibicao(nomeNormalizado);

    _configuracoes = _configuracoes.copiarComNomeExibicao(nomeNormalizado);
    if (_ativo) notifyListeners();
  }

  Future<void> salvarNotificacoes(PreferenciasNotificacoes valor) async {
    await carregar();
    await _armazenamentoNotificacoes?.salvarNotificacoes(valor);
    _configuracoes = _configuracoes.copiarComNotificacoes(valor);
    if (_ativo) notifyListeners();
  }

  @override
  void dispose() {
    _ativo = false;
    super.dispose();
  }
}
