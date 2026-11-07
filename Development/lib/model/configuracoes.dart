import 'preferencias_notificacoes.dart';

/// Preferências locais do usuário, mantidas sem exigir uma conta.
class Configuracoes {
  const Configuracoes({
    this.nomeExibicao,
    this.notificacoes = const PreferenciasNotificacoes(),
  });

  final String? nomeExibicao;
  final PreferenciasNotificacoes notificacoes;

  /// Remove espaços externos e representa um nome vazio como ausência de nome.
  static String? normalizarNomeExibicao(String? valor) {
    final normalizado = valor?.trim();
    return normalizado == null || normalizado.isEmpty ? null : normalizado;
  }

  Configuracoes copiarComNomeExibicao(String? nomeExibicao) => Configuracoes(
    nomeExibicao: normalizarNomeExibicao(nomeExibicao),
    notificacoes: notificacoes,
  );

  Configuracoes copiarComNotificacoes(PreferenciasNotificacoes valor) =>
      Configuracoes(nomeExibicao: nomeExibicao, notificacoes: valor);
}
