import 'package:flutter/material.dart';

import '../model/preferencias_notificacoes.dart';
import '../services/configuracoes_service.dart';
import '../services/notificacao_service.dart';
import '../tema/cores.dart';

/// Preferências de lembretes e notificações.
class TelaNotificacoes extends StatefulWidget {
  const TelaNotificacoes({
    super.key,
    this.notificacaoService = const NotificacaoServiceIndisponivel(),
    this.sincronizarLembretes,
    this.configuracoesService,
  });

  final NotificacaoService notificacaoService;
  final ConfiguracoesService? configuracoesService;
  final Future<RelatorioSincronizacaoLembretes> Function()?
  sincronizarLembretes;

  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes>
    with WidgetsBindingObserver {
  StatusPermissaoNotificacao? _status;
  bool _carregando = true;
  bool _salvando = false;

  Future<void> _salvar(PreferenciasNotificacoes preferencias) async {
    final configuracoes = widget.configuracoesService;
    if (_salvando || configuracoes == null) return;
    setState(() => _salvando = true);
    var mensagem = 'Não foi possível salvar as preferências.';
    try {
      await configuracoes.salvarNotificacoes(preferencias);
      mensagem = 'Preferências salvas.';
      try {
        final resultado = await widget.sincronizarLembretes?.call();
        if (resultado != null && resultado.falhas > 0) {
          mensagem =
              'Preferências salvas. Alguns lembretes não foram sincronizados.';
        }
      } catch (_) {
        mensagem =
            'Preferências salvas. Não foi possível sincronizar os lembretes.';
      }
    } catch (_) {
      // A mensagem mantém o estado da preferência anterior.
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));
    }
  }

  Future<void> _escolherHorario(PreferenciasNotificacoes preferencias) async {
    final horario = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: preferencias.minutosResumo ~/ 60,
        minute: preferencias.minutosResumo % 60,
      ),
    );
    if (horario == null || !mounted) return;
    await _salvar(
      preferencias.copiarCom(minutosResumo: horario.hour * 60 + horario.minute),
    );
  }

  Widget _preferencias(ConfiguracoesService configuracoes) => ListenableBuilder(
    listenable: configuracoes,
    builder: (context, _) {
      final p = configuracoes.configuracoes.notificacoes;
      final hora = TimeOfDay(
        hour: p.minutosResumo ~/ 60,
        minute: p.minutosResumo % 60,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sua agenda', style: Theme.of(context).textTheme.titleMedium),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Resumo diário'),
                  value: p.resumo,
                  onChanged: _salvando
                      ? null
                      : (valor) => _salvar(p.copiarCom(resumo: valor)),
                ),
                ListTile(
                  title: const Text('Horário do resumo'),
                  subtitle: Text(hora.format(context)),
                  trailing: const Icon(Icons.schedule),
                  enabled: p.resumo && !_salvando,
                  onTap: () => _escolherHorario(p),
                ),
                SwitchListTile(
                  title: const Text('Notificações por bloco'),
                  subtitle: const Text(
                    'Manhã 08:00 · tarde 12:00 · noite 18:00',
                  ),
                  value: p.blocos,
                  onChanged: _salvando
                      ? null
                      : (valor) => _salvar(p.copiarCom(blocos: valor)),
                ),
                SwitchListTile(
                  title: const Text('Lembretes individuais'),
                  value: p.individuais,
                  onChanged: _salvando
                      ? null
                      : (valor) => _salvar(p.copiarCom(individuais: valor)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Som e vibração',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Som'),
                  value: p.som,
                  onChanged: _salvando
                      ? null
                      : (valor) => _salvar(p.copiarCom(som: valor)),
                ),
                SwitchListTile(
                  title: const Text('Vibração'),
                  value: p.vibracao,
                  onChanged: _salvando
                      ? null
                      : (valor) => _salvar(p.copiarCom(vibracao: valor)),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _consultarStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_carregando) {
      _consultarStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _gerenciarNoAndroid(NotificacaoServiceAndroid servico) async {
    if (await servico.abrirConfiguracoesAndroid() || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir as configurações do Android.'),
      ),
    );
  }

  Future<void> _consultarStatus() async {
    StatusPermissaoNotificacao status;
    try {
      status = await widget.notificacaoService.consultarPermissao();
    } catch (_) {
      status = StatusPermissaoNotificacao.erro;
    }
    if (!mounted) return;
    setState(() {
      _status = status;
      _carregando = false;
    });
  }

  Future<void> _solicitarPermissao() async {
    if (_carregando) return;
    setState(() => _carregando = true);
    StatusPermissaoNotificacao status;
    RelatorioSincronizacaoLembretes? sincronizacao;
    var falhaSincronizacao = false;
    try {
      status = await widget.notificacaoService.solicitarPermissao();
    } catch (_) {
      status = StatusPermissaoNotificacao.erro;
    }
    if (status == StatusPermissaoNotificacao.permitida &&
        widget.sincronizarLembretes != null) {
      try {
        sincronizacao = await widget.sincronizarLembretes!.call();
      } catch (_) {
        falhaSincronizacao = true;
      }
    }
    if (!mounted) return;
    setState(() {
      _status = status;
      _carregando = false;
    });
    final sincronizouSemFalhas =
        sincronizacao != null &&
        sincronizacao.statusPermissao == StatusPermissaoNotificacao.permitida &&
        sincronizacao.falhas == 0;
    final mensagem = switch (status) {
      StatusPermissaoNotificacao.permitida when sincronizouSemFalhas =>
        'Notificações permitidas. Lembretes futuros foram sincronizados.',
      StatusPermissaoNotificacao.permitida
          when falhaSincronizacao ||
              (sincronizacao != null &&
                  (sincronizacao.falhas != 0 ||
                      sincronizacao.statusPermissao !=
                          StatusPermissaoNotificacao.permitida)) =>
        'Permissão concedida, mas alguns lembretes não foram sincronizados.',
      StatusPermissaoNotificacao.permitida =>
        'Notificações permitidas. Novos lembretes poderão ser agendados.',
      StatusPermissaoNotificacao.negada =>
        'Permissão recusada. As demais funções continuam disponíveis.',
      StatusPermissaoNotificacao.indisponivel =>
        'Notificações não estão disponíveis neste sistema.',
      StatusPermissaoNotificacao.erro =>
        'Não foi possível verificar a permissão agora.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoresApp.fundo,
      appBar: AppBar(
        toolbarHeight: 76,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Notificações'),
            Text(
              'Lembretes no seu ritmo',
              style: TextStyle(
                color: CoresApp.textoSecundario,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: CoresApp.principalSuave,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.alarm_outlined, color: CoresApp.principal),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lembretes individuais',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Ative um lembrete no formulário de cada tarefa e escolha a antecedência.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (widget.configuracoesService case final configuracoes?) ...[
            _preferencias(configuracoes),
            const SizedBox(height: 22),
          ],
          Text(
            'Permissão do Android',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _corStatus.withValues(alpha: 0.12),
                        foregroundColor: _corStatus,
                        child: Icon(
                          _carregando
                              ? Icons.hourglass_top_rounded
                              : _iconeStatus,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tituloStatus,
                              key: const Key('status_permissao_notificacao'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _descricaoStatus,
                              style: const TextStyle(
                                color: CoresApp.textoSecundario,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_status != StatusPermissaoNotificacao.indisponivel) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('solicitar_permissao_notificacao'),
                      onPressed: _carregando ? null : _solicitarPermissao,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: Text(
                        _status == StatusPermissaoNotificacao.permitida
                            ? 'Verificar novamente'
                            : 'Permitir notificações',
                      ),
                    ),
                    if (widget.notificacaoService
                        case final NotificacaoServiceAndroid servico)
                      TextButton.icon(
                        onPressed: _carregando
                            ? null
                            : () => _gerenciarNoAndroid(servico),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Gerenciar no Android'),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Os lembretes usam o horário e o fuso deste aparelho. O Android pode atrasar um alarme para economizar bateria.',
            style: TextStyle(color: CoresApp.textoSecundario),
          ),
        ],
      ),
    );
  }

  String get _tituloStatus {
    if (_carregando && _status == null) return 'Verificando permissão';
    return switch (_status) {
      StatusPermissaoNotificacao.permitida => 'Notificações permitidas',
      StatusPermissaoNotificacao.negada => 'Notificações não permitidas',
      StatusPermissaoNotificacao.indisponivel => 'Recurso indisponível',
      StatusPermissaoNotificacao.erro || null => 'Status não confirmado',
    };
  }

  String get _descricaoStatus => switch (_status) {
    StatusPermissaoNotificacao.permitida =>
      'Lembretes futuros podem ser agendados.',
    StatusPermissaoNotificacao.negada =>
      'As tarefas e o Foco continuam funcionando normalmente.',
    StatusPermissaoNotificacao.indisponivel =>
      'Este ambiente não oferece notificações Android.',
    StatusPermissaoNotificacao.erro ||
    null => 'Tente novamente sem perder nenhuma tarefa.',
  };

  IconData get _iconeStatus => switch (_status) {
    StatusPermissaoNotificacao.permitida => Icons.check_circle_outline_rounded,
    StatusPermissaoNotificacao.negada => Icons.notifications_off_outlined,
    StatusPermissaoNotificacao.indisponivel => Icons.block_rounded,
    StatusPermissaoNotificacao.erro || null => Icons.info_outline_rounded,
  };

  Color get _corStatus => switch (_status) {
    StatusPermissaoNotificacao.permitida => Colors.green.shade700,
    StatusPermissaoNotificacao.negada => Colors.orange.shade800,
    StatusPermissaoNotificacao.indisponivel => CoresApp.textoSecundario,
    StatusPermissaoNotificacao.erro || null => CoresApp.principal,
  };
}
