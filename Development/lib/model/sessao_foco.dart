/// Marca persistida da sessão global do modo Foco.
///
/// Uma linha sem [inicio] representa uma tarefa selecionada com o cronômetro
/// pausado. Quando [inicio] existe, o intervalo entre ele e o relógio atual é
/// apenas projetado na leitura; a soma só é consolidada na tarefa ao pausar,
/// concluir ou encerrar a sessão por outro fluxo.
class SessaoFocoPersistida {
  const SessaoFocoPersistida({
    required this.tarefaIdentificador,
    required this.inicio,
  });

  final int tarefaIdentificador;
  final DateTime? inicio;

  bool get estaEmAndamento => inicio != null;
}

/// Resultado atômico das transições persistidas do cronômetro.
enum ResultadoTransicaoFoco {
  realizada,
  semSessao,
  jaPausada,
  jaEmAndamento,
  outraTarefaEmAndamento,
  tarefaInexistente,
  tarefaConcluida,
}
