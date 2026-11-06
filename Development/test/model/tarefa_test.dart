import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_list/model/tarefa.dart';

void main() {
  group('Tarefa', () {
    test('representa uma tarefa ainda não persistida e campos opcionais', () {
      final tarefa = Tarefa(
        titulo: 'Planejar o dia',
        data: DateTime(2026, 10, 8, 14, 30),
      );

      expect(tarefa.identificador, isNull);
      expect(tarefa.descricao, isNull);
      expect(tarefa.horario, isNull);
      expect(tarefa.duracaoEstimada, isNull);
      expect(tarefa.categoria, isNull);
      expect(tarefa.tempoRegistrado, Duration.zero);
      expect(tarefa.prioridade, PrioridadeTarefa.media);
      expect(tarefa.status, StatusTarefa.pendente);
      expect(tarefa.data, DateTime(2026, 10, 8));
    });

    test('mantém estimativa e tempo registrado como valores distintos', () {
      final tarefa = Tarefa(
        identificador: 10,
        titulo: 'Revisar apresentação',
        descricao: 'Revisão final',
        data: DateTime(2026, 10, 8),
        horario: HorarioTarefa(hora: 14, minuto: 0),
        duracaoEstimada: const Duration(minutes: 45),
        tempoRegistrado: const Duration(minutes: 20),
        prioridade: PrioridadeTarefa.alta,
        categoria: 'Trabalho',
        status: StatusTarefa.pausada,
      );

      final concluida = tarefa.copiarComStatus(StatusTarefa.concluida);

      expect(tarefa.status, StatusTarefa.pausada);
      expect(concluida.status, StatusTarefa.concluida);
      expect(concluida.duracaoEstimada, const Duration(minutes: 45));
      expect(concluida.tempoRegistrado, const Duration(minutes: 20));
      expect(concluida.identificador, 10);
      expect(concluida.horario?.hora, 14);
      expect(concluida.horario?.minuto, 0);
    });
  });
}
