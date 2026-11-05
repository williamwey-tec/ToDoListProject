import 'package:flutter/material.dart';
import '../tema/cores.dart';

/// Níveis de prioridade de uma tarefa no FlowTask.
enum PrioridadeTarefa {
  baixa,
  media,
  alta,
}

/// Estados de andamento de uma tarefa no FlowTask.
enum StatusTarefa {
  pendente,
  concluida,
  atrasada,
  pausada,
}

/// Cartão com os dados, badges de prioridade/status e ações de uma tarefa.
class CardTarefa extends StatelessWidget {
  final String titulo;
  final String horario;
  final String duracaoEstimada;
  final String? tempoUsado;
  final PrioridadeTarefa prioridade;
  final StatusTarefa status;
  final VoidCallback? onTap;
  final VoidCallback? onAlternarStatus;

  const CardTarefa({
    super.key,
    required this.titulo,
    required this.horario,
    required this.duracaoEstimada,
    this.tempoUsado,
    this.prioridade = PrioridadeTarefa.media,
    this.status = StatusTarefa.pendente,
    this.onTap,
    this.onAlternarStatus,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPausada = status == StatusTarefa.pausada;
    final bool isConcluida = status == StatusTarefa.concluida;

    return Material(
      color: isPausada ? CoresApp.pausadaFundo : CoresApp.superficie,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPausada ? CoresApp.pausada : CoresApp.borda,
              width: 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ícone lateral de status (check verde, pause roxo ou círculo vazio)
              GestureDetector(
                onTap: onAlternarStatus,
                child: _construirIconeStatus(),
              ),
              const SizedBox(width: 14),

              // Conteúdo principal do card
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Linha de horário + duração e tempo usado à direita
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$horario · $duracaoEstimada',
                          style: const TextStyle(
                            color: CoresApp.textoSecundario,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (tempoUsado != null && tempoUsado!.isNotEmpty)
                          Text(
                            tempoUsado!,
                            style: const TextStyle(
                              color: CoresApp.textoSecundario,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Título da tarefa
                    Text(
                      titulo,
                      style: TextStyle(
                        color: isConcluida
                            ? CoresApp.textoSecundario
                            : CoresApp.texto,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Badges de Prioridade e Status
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _construirBadgePrioridade(),
                        _construirBadgeStatus(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirIconeStatus() {
    switch (status) {
      case StatusTarefa.concluida:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: CoresApp.concluida,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: CoresApp.sobrePrincipal,
            size: 18,
          ),
        );
      case StatusTarefa.pausada:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: CoresApp.pausada,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.pause_rounded,
            color: CoresApp.sobrePrincipal,
            size: 18,
          ),
        );
      case StatusTarefa.pendente:
      case StatusTarefa.atrasada:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: CoresApp.pendente,
              width: 1.8,
            ),
          ),
        );
    }
  }

  Widget _construirBadgePrioridade() {
    final String texto;
    final Color corFundo;
    final Color corTexto;

    switch (prioridade) {
      case PrioridadeTarefa.baixa:
        texto = 'Prioridade baixa';
        corFundo = CoresApp.prioridadeBaixaFundo;
        corTexto = CoresApp.prioridadeBaixa;
      case PrioridadeTarefa.media:
        texto = 'Prioridade média';
        corFundo = CoresApp.prioridadeMediaFundo;
        corTexto = CoresApp.prioridadeMedia;
      case PrioridadeTarefa.alta:
        texto = 'Prioridade alta';
        corFundo = CoresApp.prioridadeAltaFundo;
        corTexto = CoresApp.prioridadeAlta;
    }

    return _Badge(
      texto: texto,
      corFundo: corFundo,
      corTexto: corTexto,
    );
  }

  Widget _construirBadgeStatus() {
    switch (status) {
      case StatusTarefa.concluida:
        return const _Badge(
          texto: 'Concluída',
          corFundo: CoresApp.concluidaFundo,
          corTexto: CoresApp.concluida,
        );
      case StatusTarefa.atrasada:
        return const _Badge(
          texto: 'Atrasada',
          corFundo: CoresApp.atrasadaFundo,
          corTexto: CoresApp.atrasada,
        );
      case StatusTarefa.pendente:
        return const _Badge(
          texto: 'Pendente',
          corFundo: CoresApp.pendenteFundo,
          corTexto: CoresApp.pendente,
        );
      case StatusTarefa.pausada:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            'Pausada',
            style: TextStyle(
              color: CoresApp.pausada,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
    }
  }
}

class _Badge extends StatelessWidget {
  final String texto;
  final Color corFundo;
  final Color corTexto;

  const _Badge({
    required this.texto,
    required this.corFundo,
    required this.corTexto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: corTexto,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
