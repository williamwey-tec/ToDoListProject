import 'package:flutter/material.dart';
import '../model/tarefa.dart';
import '../tema/cores.dart';

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
  final bool exibirPrioridade;
  final bool exibirStatus;

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
    this.exibirPrioridade = true,
    this.exibirStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
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
              // Controle com área de toque mínima de 48 x 48.
              Semantics(
                button: onAlternarStatus != null,
                label: _rotuloAcaoStatus,
                child: IconButton(
                  onPressed: onAlternarStatus,
                  tooltip: onAlternarStatus == null ? null : _rotuloAcaoStatus,
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: _construirIconeStatus(),
                ),
              ),
              const SizedBox(width: 8),

              // Conteúdo principal do card
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Os textos podem ocupar mais de uma linha sem overflow.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$horario · $duracaoEstimada',
                            style: tema.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (tempoUsado != null && tempoUsado!.isNotEmpty)
                          Expanded(
                            child: Text(
                              tempoUsado!,
                              textAlign: TextAlign.end,
                              style: tema.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Título da tarefa
                    Text(
                      titulo,
                      style: tema.textTheme.titleMedium?.copyWith(
                        color: isConcluida
                            ? tema.colorScheme.onSurfaceVariant
                            : tema.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (exibirPrioridade || exibirStatus)
                      const SizedBox(height: 8),

                    // Badges de Prioridade e Status
                    if (exibirPrioridade || exibirStatus)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (exibirPrioridade) _construirBadgePrioridade(),
                          if (exibirStatus) _construirBadgeStatus(),
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

  String get _rotuloAcaoStatus => status == StatusTarefa.concluida
      ? 'Marcar tarefa como pendente'
      : 'Marcar tarefa como concluída';

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
            border: Border.all(color: CoresApp.pendente, width: 1.8),
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

    return _Badge(texto: texto, corFundo: corFundo, corTexto: corTexto);
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
