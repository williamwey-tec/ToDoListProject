import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_list/model/preferencias_notificacoes.dart';
import 'package:to_do_list/model/tarefa.dart';
import 'package:to_do_list/services/notificacao_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('dexterous.com/flutter/local_notifications');

  test(
    'Android recebe ações, opções de canal e IDs estáveis para a agenda',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final pendentes = <int, Map<Object?, Object?>>{};
      final chamadas = <MethodCall>[];
      final respostas = <RespostaLembrete>[];
      final mensageiro = binding.defaultBinaryMessenger;
      addTearDown(() {
        mensageiro.setMockMethodCallHandler(canal, null);
        debugDefaultTargetPlatformOverride = null;
      });

      mensageiro.setMockMethodCallHandler(canal, (chamada) async {
        chamadas.add(chamada);
        switch (chamada.method) {
          case 'initialize':
          case 'areNotificationsEnabled':
            return true;
          case 'getNotificationAppLaunchDetails':
            return {
              'notificationLaunchedApp': true,
              'notificationResponse': {
                'notificationId': -1,
                'actionId': 'concluir',
                'notificationResponseType': 1,
                'payload': 'agenda:10|assinatura',
              },
            };
          case 'pendingNotificationRequests':
            return pendentes.values.toList();
          case 'zonedSchedule':
            final dados = Map<Object?, Object?>.from(chamada.arguments as Map);
            pendentes[dados['id'] as int] = dados;
            return null;
          case 'cancel':
            final dados = chamada.arguments as Map;
            pendentes.remove(dados['id']);
            return null;
        }
        throw StateError(chamada.method);
      });

      final hoje = DateTime.now();
      final agora = DateTime(hoje.year, hoje.month, hoje.day + 1, 7);
      var preferencia = const PreferenciasNotificacoes(
        resumo: true,
        blocos: true,
        som: false,
        vibracao: false,
      );
      final servico = NotificacaoServiceAndroid(
        carregarPreferencias: () async => preferencia,
        onResposta: respostas.add,
      );
      final tarefa = Tarefa(
        identificador: 10,
        titulo: 'Revisar',
        data: agora,
        horario: HorarioTarefa(hora: 9, minuto: 0),
      );

      final resultado = await servico.sincronizarLembretes([
        tarefa,
      ], agora: agora);
      expect(resultado.falhas, 0);
      expect(pendentes, hasLength(2));
      expect(respostas.single.acao, AcaoNotificacao.concluir);
      expect(respostas.single.tarefaId, 10);
      expect(
        chamadas.map((c) => c.method),
        isNot(contains('requestNotificationsPermission')),
      );

      final ids = pendentes.keys.toSet();
      final dados = pendentes.values.first['platformSpecifics'] as Map;
      expect(dados['playSound'], false);
      expect(dados['enableVibration'], false);
      final acoes = (dados['actions'] as List).cast<Map>();
      expect(acoes.map((acao) => acao['id']), ['concluir', 'adiar']);
      expect(acoes.every((acao) => acao['showsUserInterface'] == true), true);

      preferencia = preferencia.copiarCom(som: true);
      await servico.sincronizarLembretes([tarefa], agora: agora);
      expect(pendentes.keys.toSet(), ids);
      expect(
        (pendentes.values.first['platformSpecifics'] as Map)['playSound'],
        true,
      );

      await servico.sincronizarLembretes([
        tarefa.copiarComStatus(StatusTarefa.concluida),
      ], agora: agora);
      expect(pendentes, isEmpty);
    },
  );
}
