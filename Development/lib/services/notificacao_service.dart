import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../model/aviso_agenda.dart';
import '../model/preferencias_notificacoes.dart';
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
      final agora = _relogio();
      final ResultadoAgendamentoLembrete resultado;
      if (atual == null) {
        await _notificacaoService.cancelarLembrete(identificador);
        resultado = ResultadoAgendamentoLembrete.desativado;
      } else {
        resultado = await _notificacaoService.agendarLembrete(
          atual,
          agora: agora,
        );
      }
      final servico = _notificacaoService;
      if (servico is NotificacaoServiceAndroid) {
        await servico.sincronizarAgenda(
          await _banco.consultarTodasTarefas(),
          agora,
        );
      }
      return resultado;
    });
  }

  Future<RelatorioSincronizacaoLembretes> sincronizar({
    List<int> removidos = const [],
  }) {
    return _emSerie(() async {
      final agora = _relogio();
      final ate = DateTime(agora.year, agora.month, agora.day + 30);
      final tarefas = await _banco.consultarTodasTarefas(materializarAte: ate);
      for (final id in removidos) {
        await _notificacaoService.cancelarLembrete(id);
      }
      return _notificacaoService.sincronizarLembretes(tarefas, agora: agora);
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

enum AcaoNotificacao { abrir, concluir, adiar }

class RespostaLembrete {
  const RespostaLembrete(this.acao, this.tarefaId);

  final AcaoNotificacao acao;
  final int tarefaId;

  static RespostaLembrete? interpretar(String? payload, String? acao) {
    final partes = payload?.split('|').first.split(':');
    if (partes == null ||
        partes.length != 2 ||
        !['tarefa', 'agenda'].contains(partes.first)) {
      return null;
    }
    final id = int.tryParse(partes.last);
    if (id == null || id <= 0) return null;
    return RespostaLembrete(switch (acao) {
      'concluir' => AcaoNotificacao.concluir,
      'adiar' => AcaoNotificacao.adiar,
      _ => AcaoNotificacao.abrir,
    }, id);
  }
}

/// Agendamento local Android com canais estáveis para cada combinação de som e vibração.
class NotificacaoServiceAndroid implements NotificacaoService {
  NotificacaoServiceAndroid({
    FlutterLocalNotificationsPlugin? plugin,
    this.carregarPreferencias,
    this.onResposta,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _icone = 'ic_stat_flowtask';
  static const _prefixoTarefa = 'tarefa:';
  static const _prefixoAgenda = 'agenda:';

  final FlutterLocalNotificationsPlugin _plugin;
  final Future<PreferenciasNotificacoes> Function()? carregarPreferencias;
  final void Function(RespostaLembrete)? onResposta;
  Future<bool>? _inicializacao;

  Future<PreferenciasNotificacoes> _preferencias() async =>
      await carregarPreferencias?.call() ?? const PreferenciasNotificacoes();

  Future<bool> abrirConfiguracoesAndroid() async {
    if (!await _garantirInicializacao()) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.openAppNotificationSettings() == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<StatusPermissaoNotificacao> consultarPermissao() => _permissao();

  @override
  Future<StatusPermissaoNotificacao> solicitarPermissao() =>
      _permissao(solicitar: true);

  Future<StatusPermissaoNotificacao> _permissao({
    bool solicitar = false,
  }) async {
    if (!await _garantirInicializacao()) {
      return StatusPermissaoNotificacao.indisponivel;
    }
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final permitida = solicitar
          ? await android?.requestNotificationsPermission()
          : await android?.areNotificationsEnabled();
      if (permitida == null) return StatusPermissaoNotificacao.erro;
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
    final id = tarefa.identificador;
    if (id == null || id <= 0) return ResultadoAgendamentoLembrete.falha;
    final preferencias = await _preferencias();
    final horario = _instanteLembrete(tarefa, preferencias);
    final permissao = await consultarPermissao();
    if (permissao == StatusPermissaoNotificacao.indisponivel) {
      return ResultadoAgendamentoLembrete.indisponivel;
    }
    if (tarefa.status == StatusTarefa.concluida ||
        horario == null ||
        !horario.isAfter(agora) ||
        permissao == StatusPermissaoNotificacao.negada) {
      await cancelarLembrete(id);
      if (tarefa.status == StatusTarefa.concluida) {
        return ResultadoAgendamentoLembrete.tarefaConcluida;
      }
      if (horario == null) {
        return tarefa.lembreteAtivo && preferencias.individuais
            ? ResultadoAgendamentoLembrete.horarioAusente
            : ResultadoAgendamentoLembrete.desativado;
      }
      return !horario.isAfter(agora)
          ? ResultadoAgendamentoLembrete.horarioPassado
          : ResultadoAgendamentoLembrete.permissaoNegada;
    }
    if (permissao != StatusPermissaoNotificacao.permitida) {
      return ResultadoAgendamentoLembrete.falha;
    }
    try {
      await _agendar(
        _avisoIndividual(tarefa, horario, preferencias),
        preferencias,
      );
      return ResultadoAgendamentoLembrete.agendadoComPossivelAtraso;
    } catch (_) {
      await cancelarLembrete(id);
      return ResultadoAgendamentoLembrete.falha;
    }
  }

  @override
  Future<void> cancelarLembrete(int tarefaIdentificador) async {
    if (!await _garantirInicializacao()) return;
    try {
      await _plugin.cancel(id: _idNotificacao(tarefaIdentificador));
    } catch (_) {
      // A persistência da tarefa não depende do Android.
    }
  }

  @override
  Future<RelatorioSincronizacaoLembretes> sincronizarLembretes(
    List<Tarefa> tarefas, {
    required DateTime agora,
  }) => _sincronizar(tarefas, agora, incluirIndividuais: true);

  Future<RelatorioSincronizacaoLembretes> sincronizarAgenda(
    List<Tarefa> tarefas,
    DateTime agora,
  ) => _sincronizar(tarefas, agora, incluirIndividuais: false);

  Future<RelatorioSincronizacaoLembretes> _sincronizar(
    List<Tarefa> tarefas,
    DateTime agora, {
    required bool incluirIndividuais,
  }) async {
    final preferencias = await _preferencias();
    final permissao = await consultarPermissao();
    var agendados = 0;
    var cancelados = 0;
    var falhas = permissao == StatusPermissaoNotificacao.erro ? 1 : 0;
    final ativos = <int>{};
    final pendentes = <int, PendingNotificationRequest>{};
    if (permissao == StatusPermissaoNotificacao.permitida ||
        permissao == StatusPermissaoNotificacao.negada) {
      try {
        for (final aviso in await _plugin.pendingNotificationRequests()) {
          final payload = aviso.payload ?? '';
          if (payload.startsWith(_prefixoAgenda) ||
              (incluirIndividuais && payload.startsWith(_prefixoTarefa))) {
            pendentes[aviso.id] = aviso;
          }
        }
        if (permissao == StatusPermissaoNotificacao.permitida) {
          final desejados = AvisoAgenda.planejar(
            tarefas,
            preferencias,
            agora,
          ).map((aviso) => _avisoAgenda(aviso, preferencias)).toList();
          if (incluirIndividuais) {
            for (final tarefa in tarefas) {
              final horario = _instanteLembrete(tarefa, preferencias);
              final limite = DateTime(agora.year, agora.month, agora.day + 30);
              if (horario != null &&
                  tarefa.identificador != null &&
                  tarefa.status != StatusTarefa.concluida &&
                  (tarefa.serieIdentificador == null ||
                      tarefa.lembreteAdiadoAte != null ||
                      horario.isBefore(limite))) {
                desejados.add(_avisoIndividual(tarefa, horario, preferencias));
              }
            }
          }
          for (final aviso in desejados) {
            final anterior = pendentes[aviso.id];
            if (anterior != null &&
                anterior.payload == aviso.payload &&
                anterior.title == aviso.titulo &&
                anterior.body == aviso.texto) {
              ativos.add(aviso.id);
            } else if (aviso.horario.isAfter(agora)) {
              try {
                await _agendar(aviso, preferencias);
                ativos.add(aviso.id);
                agendados++;
              } catch (_) {
                falhas++;
              }
            }
          }
        }
        for (final id in pendentes.keys.where((id) => !ativos.contains(id))) {
          try {
            await _plugin.cancel(id: id);
            cancelados++;
          } catch (_) {
            falhas++;
          }
        }
      } catch (_) {
        falhas++;
      }
    }
    return RelatorioSincronizacaoLembretes(
      agendados: agendados,
      cancelados: cancelados,
      falhas: falhas,
      statusPermissao: permissao,
    );
  }

  Future<bool> _garantirInicializacao() => _inicializacao ??= _inicializar();

  Future<bool> _inicializar() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final inicializada = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_icone),
        ),
        onDidReceiveNotificationResponse: _receberResposta,
      );
      if (inicializada == true && onResposta != null) {
        final abertura = await _plugin.getNotificationAppLaunchDetails();
        final resposta = abertura?.notificationResponse;
        if (abertura?.didNotificationLaunchApp == true && resposta != null) {
          _receberResposta(resposta);
        }
      }
      return inicializada == true;
    } catch (_) {
      return false;
    }
  }

  void _receberResposta(NotificationResponse resposta) {
    final acao = RespostaLembrete.interpretar(
      resposta.payload,
      resposta.actionId,
    );
    if (acao != null) onResposta?.call(acao);
  }

  DateTime? _instanteLembrete(
    Tarefa tarefa,
    PreferenciasNotificacoes preferencias,
  ) {
    if (tarefa.lembreteAdiadoAte != null) return tarefa.lembreteAdiadoAte;
    final horario = tarefa.horario;
    if (!preferencias.individuais || !tarefa.lembreteAtivo || horario == null) {
      return null;
    }
    return DateTime(
      tarefa.data.year,
      tarefa.data.month,
      tarefa.data.day,
      horario.hora,
      horario.minuto,
    ).subtract(tarefa.antecedenciaLembrete);
  }

  _AvisoAndroid _avisoIndividual(
    Tarefa tarefa,
    DateTime horario,
    PreferenciasNotificacoes preferencias,
  ) {
    final id = tarefa.identificador!;
    final minutos = tarefa.antecedenciaLembrete.inMinutes;
    return _AvisoAndroid(
      _idNotificacao(id),
      horario,
      tarefa.titulo,
      tarefa.lembreteAdiadoAte != null
          ? 'Lembrete adiado da tarefa.'
          : minutos == 0
          ? 'Está na hora desta tarefa.'
          : 'Esta tarefa começa em $minutos minutos.',
      '$_prefixoTarefa$id|${horario.millisecondsSinceEpoch}|${_canal(preferencias)}',
    );
  }

  _AvisoAndroid _avisoAgenda(
    AvisoAgenda aviso,
    PreferenciasNotificacoes preferencias,
  ) {
    final primeira = aviso.tarefas.first;
    final lista = aviso.tarefas
        .take(4)
        .map((tarefa) => '• ${tarefa.titulo}')
        .join('\n');
    final restante = aviso.tarefas.length - 4;
    final complemento = restante > 0 ? '\nE mais $restante.' : '';
    final acoes = aviso.tarefas.length > 1
        ? '\nAções para: ${primeira.titulo}'
        : '';
    return _AvisoAndroid(
      aviso.id,
      aviso.horario,
      aviso.titulo,
      '$lista$complemento$acoes',
      '$_prefixoAgenda${primeira.identificador}|${aviso.horario.millisecondsSinceEpoch}|${_canal(preferencias)}',
    );
  }

  String _canal(PreferenciasNotificacoes p) => p.som && p.vibracao
      ? 'lembretes_individuais'
      : 'flowtask_${p.som ? "som" : "mudo"}_${p.vibracao ? "vibra" : "sem_vibracao"}';

  Future<void> _agendar(_AvisoAndroid aviso, PreferenciasNotificacoes p) =>
      _plugin.zonedSchedule(
        id: aviso.id,
        title: aviso.titulo,
        body: aviso.texto,
        scheduledDate: tz.TZDateTime.from(aviso.horario.toUtc(), tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _canal(p),
            'Lembretes do FlowTask',
            channelDescription: 'Avisos de tarefas e planejamento',
            importance: Importance.high,
            priority: Priority.high,
            icon: _icone,
            playSound: p.som,
            enableVibration: p.vibracao,
            styleInformation: BigTextStyleInformation(aviso.texto),
            actions: const [
              AndroidNotificationAction(
                'concluir',
                'Concluir',
                showsUserInterface: true,
                semanticAction: SemanticAction.markAsRead,
              ),
              AndroidNotificationAction(
                'adiar',
                'Adiar 15 min',
                showsUserInterface: true,
              ),
            ],
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: aviso.payload,
      );

  int _idNotificacao(int tarefaIdentificador) =>
      tarefaIdentificador & 0x7fffffff;
}

class _AvisoAndroid {
  const _AvisoAndroid(
    this.id,
    this.horario,
    this.titulo,
    this.texto,
    this.payload,
  );

  final int id;
  final DateTime horario;
  final String titulo;
  final String texto;
  final String payload;
}
