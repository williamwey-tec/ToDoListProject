import 'package:flutter/material.dart';
import '../tema/cores.dart';

/// Indicador do progresso diário de tarefas concluídas e horas planejadas vs. realizadas.
class IndicadorProgresso extends StatelessWidget {
  final int tarefasConcluidas;
  final int totalTarefas;
  final String tempoPlanejado;
  final String tempoRealizado;
  final String rotuloPlanejado;
  final String rotuloRealizado;

  const IndicadorProgresso({
    super.key,
    required this.tarefasConcluidas,
    required this.totalTarefas,
    required this.tempoPlanejado,
    required this.tempoRealizado,
    this.rotuloPlanejado = 'Planejado',
    this.rotuloRealizado = 'Realizado',
  }) : assert(tarefasConcluidas >= 0),
       assert(totalTarefas >= 0),
       assert(tarefasConcluidas <= totalTarefas);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final double progresso = totalTarefas > 0
        ? (tarefasConcluidas / totalTarefas).clamp(0.0, 1.0)
        : 0.0;
    final int percentual = (progresso * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CoresApp.principalSuave,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quebra em telas estreitas e com fontes ampliadas.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                '$tarefasConcluidas de $totalTarefas tarefas concluídas',
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$percentual%',
                style: tema.textTheme.titleMedium?.copyWith(
                  color: tema.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barra de progresso horizontal
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progresso, minHeight: 8),
          ),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              const espacamento = 24.0;
              final duasColunas = constraints.maxWidth >= 240;
              final larguraMetrica = duasColunas
                  ? (constraints.maxWidth - espacamento) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: espacamento,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: larguraMetrica,
                    child: _MetricaProgresso(
                      rotulo: rotuloPlanejado,
                      valor: tempoPlanejado,
                      corValor: tema.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(
                    width: larguraMetrica,
                    child: _MetricaProgresso(
                      rotulo: rotuloRealizado,
                      valor: tempoRealizado,
                      corValor: tema.colorScheme.primary,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricaProgresso extends StatelessWidget {
  final String rotulo;
  final String valor;
  final Color corValor;

  const _MetricaProgresso({
    required this.rotulo,
    required this.valor,
    required this.corValor,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: tema.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: tema.textTheme.titleLarge?.copyWith(
            color: corValor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
