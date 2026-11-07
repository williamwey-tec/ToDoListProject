import '../model/sessao_foco.dart';
import '../model/tarefa.dart';
import '../services/banco_service.dart';
import '../services/notificacao_service.dart';

typedef RelogioFoco = DateTime Function();

/// Visão imutável da sessão e das tarefas usadas pela tela de Foco.
class EstadoFoco {
  const EstadoFoco({
    required this.tarefa,
    required this.inicio,
    required this.tempoAcumulado,
    required this.tarefasDisponiveis,
    required this.proximasTarefas,
  });

  final Tarefa? tarefa;
  final DateTime? inicio;
  final Duration tempoAcumulado;
  final List<Tarefa> tarefasDisponiveis;
  final List<Tarefa> proximasTarefas;

  bool get possuiTarefa => tarefa != null;
  bool get estaEmAndamento => inicio != null;

  Duration tempoUtilizadoEm(DateTime agora) {
    final inicioAtual = inicio;
    if (inicioAtual == null) return tempoAcumulado;
    final decorrido = agora.difference(inicioAtual);
    return tempoAcumulado + (decorrido.isNegative ? Duration.zero : decorrido);
  }
}

abstract interface class OperacoesFoco {
  Future<EstadoFoco> consultarEstado();

  Future<EstadoFoco> selecionarTarefa(int identificador);

  Future<EstadoFoco> iniciar();

  Future<EstadoFoco> pausar();

  Future<EstadoFoco> retomar();

  Future<EstadoFoco> concluirTarefa();
}

class FocoException implements Exception {
  const FocoException(this.mensagem);

  final String mensagem;

  @override
  String toString() => 'FocoException: $mensagem';
}

/// Coordena a sessão global do modo Foco e suas projeções para a interface.
class ControlFoco implements OperacoesFoco {
  factory ControlFoco({
    required BancoService banco,
    RelogioFoco? relogio,
    NotificacaoService? notificacaoService,
    CoordenadorLembretes? coordenadorLembretes,
  }) {
    final relogioEfetivo = relogio ?? DateTime.now;
    return ControlFoco._(
      banco,
      relogioEfetivo,
      coordenadorLembretes ??
          CoordenadorLembretes(
            banco: banco,
            notificacaoService:
                notificacaoService ?? const NotificacaoServiceIndisponivel(),
            relogio: relogioEfetivo,
          ),
    );
  }

  ControlFoco._(this._banco, this._relogio, this._coordenadorLembretes);

  final BancoService _banco;
  final RelogioFoco _relogio;
  final CoordenadorLembretes _coordenadorLembretes;

  @override
  Future<EstadoFoco> consultarEstado() async {
    final agora = _relogio();
    final sessao = await _banco.consultarSessaoFoco();
    final tarefa = sessao == null
        ? null
        : await _banco.consultarTarefaPorId(sessao.tarefaIdentificador);
    final doDia = await _banco.consultarTarefasPorData(agora);
    final disponiveis = doDia
        .where((item) => item.status != StatusTarefa.concluida)
        .toList(growable: false);
    final proximas = disponiveis
        .where((item) => item.identificador != tarefa?.identificador)
        .toList(growable: false);

    final tarefasParaSelecao = <Tarefa>[...disponiveis];
    if (tarefa != null &&
        !tarefasParaSelecao.any(
          (item) => item.identificador == tarefa.identificador,
        )) {
      tarefasParaSelecao.insert(0, tarefa);
    }

    return EstadoFoco(
      tarefa: tarefa,
      inicio: sessao?.inicio,
      tempoAcumulado: tarefa?.tempoRegistrado ?? Duration.zero,
      tarefasDisponiveis: List.unmodifiable(tarefasParaSelecao),
      proximasTarefas: List.unmodifiable(proximas),
    );
  }

  @override
  Future<EstadoFoco> selecionarTarefa(int identificador) async {
    final resultado = await _banco.selecionarTarefaFoco(identificador);
    _validarResultado(resultado, acao: 'selecionar');
    return consultarEstado();
  }

  @override
  Future<EstadoFoco> iniciar() => _iniciarOuRetomar('iniciar');

  @override
  Future<EstadoFoco> retomar() => _iniciarOuRetomar('retomar');

  Future<EstadoFoco> _iniciarOuRetomar(String acao) async {
    final sessao = await _banco.consultarSessaoFoco();
    if (sessao == null) {
      throw const FocoException('Selecione uma tarefa antes de iniciar.');
    }
    final resultado = await _banco.iniciarFoco(
      sessao.tarefaIdentificador,
      _relogio(),
    );
    _validarResultado(resultado, acao: acao, aceitarIdempotencia: true);
    return consultarEstado();
  }

  @override
  Future<EstadoFoco> pausar() async {
    final resultado = await _banco.pausarFoco(_relogio());
    _validarResultado(resultado, acao: 'pausar', aceitarIdempotencia: true);
    return consultarEstado();
  }

  @override
  Future<EstadoFoco> concluirTarefa() async {
    final sessao = await _banco.consultarSessaoFoco();
    if (sessao == null) {
      throw const FocoException('Não há tarefa selecionada para concluir.');
    }
    final tarefa = await _banco.concluirTarefaComFoco(
      sessao.tarefaIdentificador,
      _relogio(),
    );
    if (tarefa == null) {
      throw const FocoException('A tarefa selecionada não existe mais.');
    }
    try {
      await _coordenadorLembretes.reconciliarTarefa(sessao.tarefaIdentificador);
    } catch (_) {
      // A conclusão transacional permanece válida se a plataforma falhar.
    }
    return consultarEstado();
  }

  void _validarResultado(
    ResultadoTransicaoFoco resultado, {
    required String acao,
    bool aceitarIdempotencia = false,
  }) {
    if (resultado == ResultadoTransicaoFoco.realizada) return;
    if (aceitarIdempotencia &&
        (resultado == ResultadoTransicaoFoco.jaPausada ||
            resultado == ResultadoTransicaoFoco.jaEmAndamento)) {
      return;
    }
    final mensagem = switch (resultado) {
      ResultadoTransicaoFoco.semSessao =>
        'Selecione uma tarefa antes de $acao.',
      ResultadoTransicaoFoco.jaPausada => 'O cronômetro já está pausado.',
      ResultadoTransicaoFoco.jaEmAndamento =>
        'O cronômetro já está em andamento.',
      ResultadoTransicaoFoco.outraTarefaEmAndamento =>
        'Pause a tarefa atual antes de iniciar outra.',
      ResultadoTransicaoFoco.tarefaInexistente =>
        'A tarefa selecionada não existe mais.',
      ResultadoTransicaoFoco.tarefaConcluida =>
        'Uma tarefa concluída não pode iniciar o foco.',
      ResultadoTransicaoFoco.realizada => throw StateError('Inalcançável.'),
    };
    throw FocoException(mensagem);
  }
}
