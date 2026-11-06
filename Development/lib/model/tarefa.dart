/// Níveis de prioridade de uma tarefa no FlowTask.
enum PrioridadeTarefa { baixa, media, alta }

/// Estados de andamento de uma tarefa no FlowTask.
enum StatusTarefa { pendente, concluida, atrasada, pausada }

/// Horário civil de uma tarefa, sem data ou fuso horário associados.
///
/// Manter hora e minuto em um tipo próprio evita acoplar o modelo compartilhado
/// a widgets do Flutter e impede que um texto livre represente um horário.
class HorarioTarefa {
  final int hora;
  final int minuto;

  HorarioTarefa({required this.hora, required this.minuto}) {
    if (hora < 0 || hora > 23) {
      throw RangeError.range(hora, 0, 23, 'hora');
    }
    if (minuto < 0 || minuto > 59) {
      throw RangeError.range(minuto, 0, 59, 'minuto');
    }
  }
}

/// Contrato compartilhado dos dados de uma tarefa.
///
/// [identificador] é nulo enquanto a tarefa ainda não foi persistida. A
/// [descricao], o [horario], a [duracaoEstimada] e a [categoria] também são
/// opcionais. [tempoRegistrado] representa somente o tempo efetivamente
/// contabilizado e começa em zero; ele nunca é derivado de
/// [duracaoEstimada].
///
/// [data] armazena apenas o dia civil: hora, minuto, segundo e microssegundo
/// recebidos são descartados. As instâncias são imutáveis; mudanças de estado
/// devem criar outra instância, por exemplo com [copiarComStatus].
class Tarefa {
  final int? identificador;
  final String titulo;
  final String? descricao;
  final DateTime data;
  final HorarioTarefa? horario;
  final Duration? duracaoEstimada;
  final Duration tempoRegistrado;
  final PrioridadeTarefa prioridade;
  final String? categoria;
  final StatusTarefa status;

  Tarefa({
    this.identificador,
    required this.titulo,
    this.descricao,
    required DateTime data,
    this.horario,
    this.duracaoEstimada,
    this.tempoRegistrado = Duration.zero,
    this.prioridade = PrioridadeTarefa.media,
    this.categoria,
    this.status = StatusTarefa.pendente,
  }) : data = DateTime(data.year, data.month, data.day);

  /// Cria uma nova tarefa preservando todos os dados e alterando o estado.
  Tarefa copiarComStatus(StatusTarefa novoStatus) {
    return Tarefa(
      identificador: identificador,
      titulo: titulo,
      descricao: descricao,
      data: data,
      horario: horario,
      duracaoEstimada: duracaoEstimada,
      tempoRegistrado: tempoRegistrado,
      prioridade: prioridade,
      categoria: categoria,
      status: novoStatus,
    );
  }
}
