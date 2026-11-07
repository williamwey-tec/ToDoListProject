/// Preferências locais do usuário, mantidas sem exigir uma conta.
class Configuracoes {
  const Configuracoes({this.nomeExibicao});

  final String? nomeExibicao;

  /// Remove espaços externos e representa um nome vazio como ausência de nome.
  static String? normalizarNomeExibicao(String? valor) {
    final normalizado = valor?.trim();
    return normalizado == null || normalizado.isEmpty ? null : normalizado;
  }

  Configuracoes copiarComNomeExibicao(String? nomeExibicao) =>
      Configuracoes(nomeExibicao: normalizarNomeExibicao(nomeExibicao));
}
