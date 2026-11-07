import '../model/tarefa.dart';
import '../services/banco_service.dart';
import '../services/notificacao_service.dart';

/// Relógio local usado para decidir se uma tarefa está atrasada.
///
/// O valor deve seguir a mesma convenção civil local de [Tarefa.data].
typedef RelogioTarefa = DateTime Function();

/// Operações consumidas pelas telas de cadastro e consulta.
///
/// O contrato permite injetar uma implementação determinística nos testes de
/// interface sem trocar as regras usadas pelo aplicativo, implementadas por
/// [ControlTarefa].
abstract interface class OperacoesTarefa {
  Future<Tarefa> criarTarefa(Tarefa tarefa);

  Future<Tarefa?> consultarTarefaPorId(int identificador);

  Future<List<Tarefa>> consultarTarefasPorData(DateTime data);

  Future<List<Tarefa>> consultarTarefasPorIntervalo(
    DateTime dataInicial,
    DateTime dataFinal,
  );

  Future<Tarefa> editarTarefa(int identificador, Tarefa dadosEditados);

  Future<Tarefa> concluirTarefa(int identificador);

  Future<Tarefa> reabrirTarefa(int identificador);

  Future<void> excluirTarefa(int identificador);
}

/// Operações adicionais de lembrete usadas sem ampliar o contrato das telas.
abstract interface class OperacoesLembreteTarefa {
  ResultadoAgendamentoLembrete? get ultimoResultadoAgendamento;

  Future<RelatorioSincronizacaoLembretes> sincronizarLembretes();
}

/// Erro de validação de dados recebidos pelo [ControlTarefa].
class ValidacaoTarefaException implements Exception {
  const ValidacaoTarefaException(this.mensagem);

  final String mensagem;

  @override
  String toString() => 'ValidacaoTarefaException: $mensagem';
}

/// Erro retornado quando uma operação exige uma tarefa persistida inexistente.
class TarefaNaoEncontradaException implements Exception {
  const TarefaNaoEncontradaException(this.identificador);

  final int identificador;

  @override
  String toString() =>
      'TarefaNaoEncontradaException: tarefa $identificador não encontrada.';
}

/// Erro retornado quando uma transição não é válida para o estado atual.
class TransicaoTarefaException implements Exception {
  const TransicaoTarefaException(this.mensagem);

  final String mensagem;

  @override
  String toString() => 'TransicaoTarefaException: $mensagem';
}

/// Coordena persistência e regras de negócio das tarefas.
///
/// Contrato para a FT-06:
///
/// * [criarTarefa] recebe uma tarefa ainda sem ID e retorna a cópia persistida
///   com o ID gerado;
/// * [editarTarefa], [concluirTarefa] e [reabrirTarefa] retornam a versão
///   persistida e lançam [TarefaNaoEncontradaException] para um ID inexistente;
/// * [consultarTarefaPorId] retorna `null` quando o ID não existe;
/// * consultas por data e intervalo mantêm a ordenação do [BancoService]:
///   data, horário, tarefas sem horário e ID como desempate;
/// * [excluirTarefa] conclui sem valor quando exclui e lança
///   [TarefaNaoEncontradaException] quando nada é excluído.
///
/// O atraso é uma projeção calculada com o [relogio] em cada retorno. No
/// banco, uma tarefa ativa permanece `pendente`; assim, editar ou reabrir não
/// congela um estado derivado. Tarefas concluídas ou pausadas nunca são
/// apresentadas como atrasadas.
class ControlTarefa implements OperacoesTarefa, OperacoesLembreteTarefa {
  factory ControlTarefa({
    required BancoService banco,
    RelogioTarefa? relogio,
    NotificacaoService? notificacaoService,
    CoordenadorLembretes? coordenadorLembretes,
  }) {
    final relogioEfetivo = relogio ?? DateTime.now;
    return ControlTarefa._(
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

  ControlTarefa._(this._banco, this._relogio, this._coordenadorLembretes);

  final BancoService _banco;
  final RelogioTarefa _relogio;
  final CoordenadorLembretes _coordenadorLembretes;

  @override
  ResultadoAgendamentoLembrete? ultimoResultadoAgendamento;

  /// Valida e persiste uma nova tarefa, retornando-a com o ID gerado.
  @override
  Future<Tarefa> criarTarefa(Tarefa tarefa) async {
    if (tarefa.identificador != null) {
      throw const ValidacaoTarefaException(
        'Uma nova tarefa não pode ter identificador.',
      );
    }

    final normalizada = _normalizarParaPersistencia(tarefa);
    _validarDadosEditaveis(normalizada);

    final identificador = await _banco.inserirTarefa(normalizada);
    final persistida = await _banco.consultarTarefaPorId(identificador);
    if (persistida == null) {
      throw StateError(
        'A tarefa $identificador foi inserida, mas não pôde ser consultada.',
      );
    }
    final exibida = _aplicarAtraso(persistida);
    ultimoResultadoAgendamento = await _agendarSemFalhar(exibida);
    return exibida;
  }

  /// Consulta pelo ID e projeta o atraso atual, ou retorna `null`.
  @override
  Future<Tarefa?> consultarTarefaPorId(int identificador) async {
    _validarIdentificador(identificador);
    final tarefa = await _banco.consultarTarefaPorId(identificador);
    if (tarefa == null) return null;
    final agora = _relogio();
    return _aplicarAtraso(await _aplicarFocoAtivo(tarefa, agora), agora);
  }

  /// Consulta um dia civil na ordem definida pelo [BancoService].
  @override
  Future<List<Tarefa>> consultarTarefasPorData(DateTime data) async {
    final tarefas = await _banco.consultarTarefasPorData(data);
    return _aplicarFocoEAtrasoEmTodas(tarefas);
  }

  /// Consulta um intervalo civil inclusivo na ordem do [BancoService].
  @override
  Future<List<Tarefa>> consultarTarefasPorIntervalo(
    DateTime dataInicial,
    DateTime dataFinal,
  ) async {
    final tarefas = await _banco.consultarTarefasPorIntervalo(
      dataInicial,
      dataFinal,
    );
    return _aplicarFocoEAtrasoEmTodas(tarefas);
  }

  /// Altera os dados editáveis preservando ID, tempo registrado e situação.
  ///
  /// O identificador presente em [dadosEditados] é ignorado. Descrição e
  /// categoria continuam opcionais; título, horário e duração estimada são
  /// obrigatórios para uma edição válida.
  @override
  Future<Tarefa> editarTarefa(int identificador, Tarefa dadosEditados) async {
    _validarIdentificador(identificador);
    final atual = await _obterExistente(identificador);
    final editada = Tarefa(
      identificador: identificador,
      titulo: dadosEditados.titulo.trim(),
      descricao: dadosEditados.descricao,
      data: dadosEditados.data,
      horario: dadosEditados.horario,
      duracaoEstimada: dadosEditados.duracaoEstimada,
      tempoRegistrado: atual.tempoRegistrado,
      prioridade: dadosEditados.prioridade,
      categoria: dadosEditados.categoria,
      status: _statusPersistivel(atual.status),
      lembreteAtivo: dadosEditados.lembreteAtivo,
      antecedenciaLembrete: dadosEditados.antecedenciaLembrete,
    );
    _validarDadosEditaveis(editada);

    final alteradas = await _banco.atualizarCamposEditaveisTarefa(
      identificador,
      editada,
    );
    if (alteradas == 0) {
      throw TarefaNaoEncontradaException(identificador);
    }
    final persistida = await _obterExistente(identificador);
    final exibida = _aplicarAtraso(persistida);
    ultimoResultadoAgendamento = await _agendarSemFalhar(exibida);
    return exibida;
  }

  /// Marca a tarefa como concluída, preservando todos os demais dados.
  @override
  Future<Tarefa> concluirTarefa(int identificador) async {
    _validarIdentificador(identificador);
    final concluida = await _banco.concluirTarefaComFoco(
      identificador,
      _relogio(),
    );
    if (concluida == null) {
      throw TarefaNaoEncontradaException(identificador);
    }
    await _cancelarSemFalhar(identificador);
    ultimoResultadoAgendamento = ResultadoAgendamentoLembrete.tarefaConcluida;
    return concluida;
  }

  /// Reabre uma tarefa concluída e recalcula imediatamente seu atraso.
  @override
  Future<Tarefa> reabrirTarefa(int identificador) async {
    _validarIdentificador(identificador);
    final atual = await _obterExistente(identificador);
    if (atual.status != StatusTarefa.concluida) {
      throw TransicaoTarefaException(
        'Somente uma tarefa concluída pode ser reaberta; '
        'a tarefa $identificador está ${atual.status.name}.',
      );
    }

    final reaberta = atual.copiarComStatus(StatusTarefa.pendente);
    await _atualizarExistente(identificador, reaberta);
    final exibida = _aplicarAtraso(reaberta);
    ultimoResultadoAgendamento = await _agendarSemFalhar(exibida);
    return exibida;
  }

  /// Exclui uma tarefa pelo ID.
  @override
  Future<void> excluirTarefa(int identificador) async {
    _validarIdentificador(identificador);
    final excluidas = await _banco.excluirTarefaComFoco(
      identificador,
      _relogio(),
    );
    if (excluidas == 0) {
      throw TarefaNaoEncontradaException(identificador);
    }
    await _cancelarSemFalhar(identificador);
  }

  Future<Tarefa> _obterExistente(int identificador) async {
    final tarefa = await _banco.consultarTarefaPorId(identificador);
    if (tarefa == null) {
      throw TarefaNaoEncontradaException(identificador);
    }
    return tarefa;
  }

  Future<void> _atualizarExistente(int identificador, Tarefa tarefa) async {
    final alteradas = await _banco.atualizarTarefa(identificador, tarefa);
    if (alteradas == 0) {
      throw TarefaNaoEncontradaException(identificador);
    }
  }

  Tarefa _normalizarParaPersistencia(Tarefa tarefa) {
    return Tarefa(
      titulo: tarefa.titulo.trim(),
      descricao: tarefa.descricao,
      data: tarefa.data,
      horario: tarefa.horario,
      duracaoEstimada: tarefa.duracaoEstimada,
      tempoRegistrado: tarefa.tempoRegistrado,
      prioridade: tarefa.prioridade,
      categoria: tarefa.categoria,
      status: _statusPersistivel(tarefa.status),
      lembreteAtivo: tarefa.lembreteAtivo,
      antecedenciaLembrete: tarefa.antecedenciaLembrete,
    );
  }

  void _validarDadosEditaveis(Tarefa tarefa) {
    if (tarefa.titulo.isEmpty) {
      throw const ValidacaoTarefaException(
        'O título deve conter ao menos um caractere não branco.',
      );
    }
    if (tarefa.horario == null) {
      throw const ValidacaoTarefaException('O horário é obrigatório.');
    }
    final duracao = tarefa.duracaoEstimada;
    if (duracao == null || duracao <= Duration.zero) {
      throw const ValidacaoTarefaException(
        'A duração estimada deve ser maior que zero.',
      );
    }
  }

  void _validarIdentificador(int identificador) {
    if (identificador <= 0) {
      throw const ValidacaoTarefaException(
        'O identificador deve ser maior que zero.',
      );
    }
  }

  Future<List<Tarefa>> _aplicarFocoEAtrasoEmTodas(List<Tarefa> tarefas) async {
    final agora = _relogio();
    final comFoco = await _aplicarFocoAtivoEmTodas(tarefas, agora);
    return comFoco
        .map((tarefa) => _aplicarAtraso(tarefa, agora))
        .toList(growable: false);
  }

  Future<List<Tarefa>> _aplicarFocoAtivoEmTodas(
    List<Tarefa> tarefas,
    DateTime agora,
  ) async {
    final sessao = await _banco.consultarSessaoFoco();
    if (sessao?.inicio == null) return tarefas;
    final decorrido = agora.difference(sessao!.inicio!);
    if (decorrido.isNegative) return tarefas;
    return tarefas
        .map(
          (tarefa) => tarefa.identificador == sessao.tarefaIdentificador
              ? _copiarComTempo(tarefa, tarefa.tempoRegistrado + decorrido)
              : tarefa,
        )
        .toList(growable: false);
  }

  Future<Tarefa> _aplicarFocoAtivo(Tarefa tarefa, DateTime agora) async {
    final tarefas = await _aplicarFocoAtivoEmTodas([tarefa], agora);
    return tarefas.single;
  }

  Tarefa _copiarComTempo(Tarefa tarefa, Duration tempoRegistrado) {
    return Tarefa(
      identificador: tarefa.identificador,
      titulo: tarefa.titulo,
      descricao: tarefa.descricao,
      data: tarefa.data,
      horario: tarefa.horario,
      duracaoEstimada: tarefa.duracaoEstimada,
      tempoRegistrado: tempoRegistrado,
      prioridade: tarefa.prioridade,
      categoria: tarefa.categoria,
      status: tarefa.status,
      lembreteAtivo: tarefa.lembreteAtivo,
      antecedenciaLembrete: tarefa.antecedenciaLembrete,
    );
  }

  @override
  Future<RelatorioSincronizacaoLembretes> sincronizarLembretes() async {
    try {
      return await _coordenadorLembretes.sincronizar();
    } catch (_) {
      return const RelatorioSincronizacaoLembretes(
        agendados: 0,
        cancelados: 0,
        falhas: 1,
        statusPermissao: StatusPermissaoNotificacao.erro,
      );
    }
  }

  Future<ResultadoAgendamentoLembrete> _agendarSemFalhar(Tarefa tarefa) async {
    try {
      return await _coordenadorLembretes.reconciliarTarefa(
        tarefa.identificador!,
      );
    } catch (_) {
      return ResultadoAgendamentoLembrete.falha;
    }
  }

  Future<void> _cancelarSemFalhar(int identificador) async {
    try {
      await _coordenadorLembretes.reconciliarTarefa(identificador);
    } catch (_) {}
  }

  Tarefa _aplicarAtraso(Tarefa tarefa, [DateTime? agora]) {
    if (tarefa.status == StatusTarefa.concluida ||
        tarefa.status == StatusTarefa.pausada) {
      return tarefa;
    }

    final horario = tarefa.horario;
    final estaAtrasada =
        horario != null &&
        DateTime(
          tarefa.data.year,
          tarefa.data.month,
          tarefa.data.day,
          horario.hora,
          horario.minuto,
        ).isBefore(agora ?? _relogio());
    return tarefa.copiarComStatus(
      estaAtrasada ? StatusTarefa.atrasada : StatusTarefa.pendente,
    );
  }

  StatusTarefa _statusPersistivel(StatusTarefa status) {
    return status == StatusTarefa.atrasada ? StatusTarefa.pendente : status;
  }
}
