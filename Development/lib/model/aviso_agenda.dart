import 'preferencias_notificacoes.dart';
import 'tarefa.dart';

class AvisoAgenda {
  const AvisoAgenda({
    required this.id,
    required this.horario,
    required this.titulo,
    required this.tarefas,
  });

  final int id;
  final DateTime horario;
  final String titulo;
  final List<Tarefa> tarefas;

  static List<AvisoAgenda> planejar(
    List<Tarefa> tarefas,
    PreferenciasNotificacoes preferencias,
    DateTime agora,
  ) {
    if (!preferencias.resumo && !preferencias.blocos) return [];
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final limite = DateTime(hoje.year, hoje.month, hoje.day + 30);
    final dias = <DateTime, List<Tarefa>>{};
    for (final tarefa in tarefas) {
      if (tarefa.status == StatusTarefa.concluida ||
          tarefa.identificador == null ||
          tarefa.data.isBefore(hoje) ||
          !tarefa.data.isBefore(limite)) {
        continue;
      }
      dias.putIfAbsent(tarefa.data, () => []).add(tarefa);
    }

    final avisos = <AvisoAgenda>[];
    for (final entrada in dias.entries) {
      final dia = entrada.key;
      final tarefasDoDia = entrada.value;
      final codigoDia = dia.year * 10000 + dia.month * 100 + dia.day;

      void incluir(int tipo, int minutos, String titulo, List<Tarefa> itens) {
        final horario = DateTime(
          dia.year,
          dia.month,
          dia.day,
          minutos ~/ 60,
          minutos % 60,
        );
        if (itens.isEmpty) return;
        avisos.add(
          AvisoAgenda(
            id: -(codigoDia * 10 + tipo),
            horario: horario,
            titulo: titulo,
            tarefas: itens,
          ),
        );
      }

      if (preferencias.resumo) {
        final quantidade = tarefasDoDia.length;
        incluir(
          0,
          preferencias.minutosResumo,
          quantidade == 1
              ? 'Você tem 1 tarefa para hoje'
              : 'Você tem $quantidade tarefas para hoje',
          tarefasDoDia,
        );
      }
      if (preferencias.blocos) {
        for (final (tipo, inicio, fim, nome) in [
          (1, 0, 12, 'manhã'),
          (2, 12, 18, 'tarde'),
          (3, 18, 24, 'noite'),
        ]) {
          incluir(
            tipo,
            (inicio == 0 ? 8 : inicio) * 60,
            'Tarefas da $nome',
            tarefasDoDia.where((tarefa) {
              final hora = tarefa.horario?.hora;
              return hora != null && hora >= inicio && hora < fim;
            }).toList(),
          );
        }
      }
    }
    return avisos;
  }
}
