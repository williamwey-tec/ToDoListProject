import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../model/tarefa.dart';
import 'banco_service.dart';

enum StatusPermissaoNotificacao { permitida, negada, indisponivel, erro }

enum ResultadoAgendamentoLembrete {
  agendadoComPossivelAtraso,
  desativado,
  tarefaConcluida,
  horarioAusente,
  horarioPassado,
  permissaoNegada,
  indisponivel,
  falha,
}

class RelatorioSincronizacaoLembretes {
  const RelatorioSincronizacaoLembretes({
    required this.agendados,
    required this.cancelados,
    required this.falhas,
    required this.statusPermissao,
  });

  final int agendados;
  final int cancelados;
  final int falhas;
  final StatusPermissaoNotificacao statusPermissao;
}

/// Contrato isolado para permitir testes sem acessar APIs nativas.
abstract interface class NotificacaoService {
  Future<StatusPermissaoNotificacao> consultarPermissao();

  /// Deve ser chamado somente após uma ação explícita da pessoa usuária.
  Future<StatusPermissaoNotificacao> solicitarPermissao();

  Future<ResultadoAgendamentoLembrete> agendarLembrete(
    Tarefa tarefa, {
    required DateTime agora,
  });

  Future<void> cancelarLembrete(int tarefaIdentificador);

  Future<RelatorioSincronizacaoLembretes> sincronizarLembretes(
    List<Tarefa> tarefas, {
    required DateTime agora,
  });
}

/// Serializa toda reconciliação e lê o estado persistido dentro da fila.
///
/// Assim uma sincronização iniciada junto com editar, concluir ou excluir não
/// consegue restaurar um agendamento baseado em uma cópia antiga da tarefa.
class CoordenadorLembretes {
  factory CoordenadorLembretes({
    required BancoService banco,
    required NotificacaoService notificacaoService,
    required DateTime Function() relogio,
  }) => CoordenadorLembretes._(banco, notificacaoService, relogio);

  CoordenadorLembretes._(this._banco, this._notificacaoService, this._relogio);

  final BancoService _banco;
  final NotificacaoService _notificacaoService;
  final DateTime Function() _relogio;
  Future<void> _fila = Future<void>.value();

  Future<ResultadoAgendamentoLembrete> reconciliarTarefa(int identificador) {
    return _emSerie(() async {
      final atual = await _banco.consultarTarefaPorId(identificador);
      if (atual == null) {
        await _notificacaoService.cancelarLembrete(identificador);
        return ResultadoAgendamentoLembrete.desativado;
      }
      return _notificacaoService.agendarLembrete(atual, agora: _relogio());
    });
  }

  Future<RelatorioSincronizacaoLembretes> sincronizar() {
    return _emSerie(() async {
      final tarefas = await _banco.consultarTodasTarefas();
      return _notificacaoService.sincronizarLembretes(
        tarefas,
        agora: _relogio(),
      );
    });
  }

  Future<T> _emSerie<T>(Future<T> Function() operacao) {
    final resultado = _fila.then((_) => operacao());
    _fila = resultado.then<void>((_) {}, onError: (_, _) {});
    return resultado;
  }
}

/// Implementação segura usada fora do Android e quando o recurso não existe.
class NotificacaoServiceIndisponivel implements NotificacaoService {
  const NotificacaoServiceIndisponivel();

  @override
  Future<StatusPermissaoNotificacao> consultarPermissao() async =>
      StatusPermissaoNotificacao.indisponivel;

  @override
  Future<StatusPermissaoNotificacao> solicitarPermissao() async =>
      StatusPermissaoNotificacao.indisponivel;

  @override
  Future<ResultadoAgendamentoLembrete> agendarLembrete(
    Tarefa tarefa, {
    required DateTime agora,
  }) async => ResultadoAgendamentoLembrete.indisponivel;

  @override
  Future<void> cancelarLembrete(int tarefaIdentificador) async {}

  @override
  Future<RelatorioSincronizacaoLembretes> sincronizarLembretes(
    List<Tarefa> tarefas, {
    required DateTime agora,
  }) async => const RelatorioSincronizacaoLembretes(
    agendados: 0,
    cancelados: 0,
    falhas: 0,
    statusPermissao: StatusPermissaoNotificacao.indisponivel,
  );
}

/// Agenda um único lembrete inexato por tarefa no Android.
///
/// O modo inexato evita exigir o acesso especial a alarmes exatos. O Android
/// pode atrasar a entrega para economizar bateria, por isso o resultado deixa
/// essa limitação explícita para a interface.
class NotificacaoServiceAndroid implements NotificacaoService {
  NotificacaoServiceAndroid({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _canalId = 'lembretes_individuais';
  static const _prefixoPayload = 'tarefa:';
  static const _icone = 'ic_stat_flowtask';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _inicializacao;

  @override
  Future<StatusPermissaoNotificacao> consultarPermissao() async {
    if (!await _garantirInicializacao()) {
      return StatusPermissaoNotificacao.indisponivel;
    }
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final permitida = await android?.areNotificationsEnabled();
      if (permitida == null) return StatusPermissaoNotificacao.erro;
      return permitida
          ? StatusPermissaoNotificacao.permitida
          : StatusPermissaoNotificacao.negada;
    } catch (_) {
      return StatusPermissaoNotificacao.erro;
    }
  }

  @override
  Future<StatusPermissaoNotificacao> solicitarPermissao() async {
    if (!await _garantirInicializacao()) {
      return StatusPermissaoNotificacao.indisponivel;
    }
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final permitida = await android?.requestNotificationsPermission();
      if (permitida == null) return await consultarPermissao();
      return permitida
          ? StatusPermissaoNotificacao.permitida
          : StatusPermissaoNotificacao.negada;
    } catch (_) {
      return StatusPermissaoNotificacao.erro;
    }
  }

  @override
  Future<ResultadoAgendamentoLembrete> agendarLembrete(
    Tarefa tarefa, {
    required DateTime agora,
  }) async {
    final identificador = tarefa.identificador;
    if (identificador == null || identificador <= 0) {
      return ResultadoAgendamentoLembrete.falha;
    }
    if (!tarefa.lembreteAtivo) {
      await _cancelarSemFalhar(identificador);
      return ResultadoAgendamentoLembrete.desativado;
    }
    if (tarefa.status == StatusTarefa.concluida) {
      await _cancelarSemFalhar(identificador);
      return ResultadoAgendamentoLembrete.tarefaConcluida;
    }
    final horario = tarefa.horario;
    if (horario == null) {
      await _cancelarSemFalhar(identificador);
      return ResultadoAgendamentoLembrete.horarioAusente;
    }

    final instanteLocal = DateTime(
      tarefa.data.year,
      tarefa.data.month,
      tarefa.data.day,
      horario.hora,
      horario.minuto,
    ).subtract(tarefa.antecedenciaLembrete);
    if (!instanteLocal.isAfter(agora)) {
      await _cancelarSemFalhar(identificador);
      return ResultadoAgendamentoLembrete.horarioPassado;
    }

    final permissao = await consultarPermissao();
    if (permissao == StatusPermissaoNotificacao.negada) {
      await _cancelarSemFalhar(identificador);
      return ResultadoAgendamentoLembrete.permissaoNegada;
    }
    if (permissao == StatusPermissaoNotificacao.indisponivel) {
      return ResultadoAgendamentoLembrete.indisponivel;
    }
    if (permissao != StatusPermissaoNotificacao.permitida) {
      return ResultadoAgendamentoLembrete.falha;
    }

    try {
      await _agendarNoPlugin(tarefa, horario);
      return ResultadoAgendamentoLembrete.agendadoComPossivelAtraso;
    } catch (_) {
      return ResultadoAgendamentoLembrete.falha;
    }
  }

  @override
  Future<void> cancelarLembrete(int tarefaIdentificador) async {
    if (!await _garantirInicializacao()) return;
    try {
      await _plugin.cancel(id: _idNotificacao(tarefaIdentificador));
    } catch (_) {
      // A persistência da tarefa nunca depende da disponibilidade do plugin.
    }
  }

  @override
  Future<RelatorioSincronizacaoLembretes> sincronizarLembretes(
    List<Tarefa> tarefas, {
    required DateTime agora,
  }) async {
    if (!await _garantirInicializacao()) {
      return const RelatorioSincronizacaoLembretes(
        agendados: 0,
        cancelados: 0,
        falhas: 0,
        statusPermissao: StatusPermissaoNotificacao.indisponivel,
      );
    }

    final permissao = await consultarPermissao();
    final configuradas = tarefas
        .where((tarefa) {
          if (!tarefa.lembreteAtivo ||
              tarefa.status == StatusTarefa.concluida ||
              tarefa.identificador == null ||
              tarefa.horario == null) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    var cancelados = 0;
    var agendados = 0;
    var falhas = 0;
    final pendentesPorId = <int, PendingNotificationRequest>{};
    try {
      final pendentes = await _plugin.pendingNotificationRequests();
      for (final pendente in pendentes) {
        if (pendente.payload?.startsWith(_prefixoPayload) ?? false) {
          pendentesPorId[pendente.id] = pendente;
        }
      }
    } catch (_) {
      falhas++;
    }

    final idsDesejados = <int>{};
    if (permissao == StatusPermissaoNotificacao.permitida) {
      for (final tarefa in configuradas) {
        final id = _idNotificacao(tarefa.identificador!);
        final pendente = pendentesPorId[id];
        final alvoFuturo = _instanteLocalDoLembrete(tarefa).isAfter(agora);
        final pendenteInalterado =
            pendente?.payload == _payloadDaTarefa(tarefa);
        if (!alvoFuturo && pendenteInalterado) {
          // Alarmes inexatos podem legitimamente continuar pendentes após o
          // alvo. Preservá-los evita recriar no passado ou cancelar um atraso
          // que o próprio Android ainda pretende entregar.
          idsDesejados.add(id);
          continue;
        }
        if (!alvoFuturo) continue;
        try {
          await _agendarNoPlugin(tarefa, tarefa.horario!);
          idsDesejados.add(id);
          agendados++;
        } catch (_) {
          falhas++;
        }
      }
    }
    for (final pendente in pendentesPorId.values) {
      if (!idsDesejados.contains(pendente.id)) {
        try {
          await _plugin.cancel(id: pendente.id);
          cancelados++;
        } catch (_) {
          falhas++;
        }
      }
    }
    return RelatorioSincronizacaoLembretes(
      agendados: agendados,
      cancelados: cancelados,
      falhas: falhas,
      statusPermissao: permissao,
    );
  }

  Future<bool> _garantirInicializacao() {
    return _inicializacao ??= _inicializar();
  }

  Future<bool> _inicializar() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final inicializada = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_icone),
        ),
      );
      return inicializada == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _agendarNoPlugin(Tarefa tarefa, HorarioTarefa horario) async {
    final inicioLocal = DateTime(
      tarefa.data.year,
      tarefa.data.month,
      tarefa.data.day,
      horario.hora,
      horario.minuto,
    );
    final instanteLocal = inicioLocal.subtract(tarefa.antecedenciaLembrete);
    final instante = tz.TZDateTime.from(instanteLocal.toUtc(), tz.UTC);
    final antecedencia = tarefa.antecedenciaLembrete.inMinutes;
    await _plugin.zonedSchedule(
      id: _idNotificacao(tarefa.identificador!),
      title: tarefa.titulo,
      body: antecedencia == 0
          ? 'Está na hora desta tarefa.'
          : 'Esta tarefa começa em $antecedencia minutos.',
      scheduledDate: instante,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _canalId,
          'Lembretes individuais',
          channelDescription: 'Lembretes configurados em cada tarefa',
          importance: Importance.high,
          priority: Priority.high,
          icon: _icone,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _payloadDaTarefa(tarefa),
    );
  }

  DateTime _instanteLocalDoLembrete(Tarefa tarefa) {
    final horario = tarefa.horario!;
    return DateTime(
      tarefa.data.year,
      tarefa.data.month,
      tarefa.data.day,
      horario.hora,
      horario.minuto,
    ).subtract(tarefa.antecedenciaLembrete);
  }

  String _payloadDaTarefa(Tarefa tarefa) {
    final horario = tarefa.horario!;
    final data = tarefa.data;
    return '$_prefixoPayload${tarefa.identificador}|'
        '${data.year}-${data.month}-${data.day}|'
        '${horario.hora}:${horario.minuto}|'
        '${tarefa.antecedenciaLembrete.inMinutes}|'
        '${_instanteLocalDoLembrete(tarefa).timeZoneOffset.inMinutes}|'
        '${Uri.encodeComponent(tarefa.titulo)}';
  }

  Future<void> _cancelarSemFalhar(int identificador) async {
    try {
      await cancelarLembrete(identificador);
    } catch (_) {}
  }

  int _idNotificacao(int tarefaIdentificador) =>
      tarefaIdentificador & 0x7fffffff;
}
