import 'package:flutter/material.dart';

import '../services/notificacao_service.dart';
import '../tema/cores.dart';

/// Preferências de lembretes e notificações.
class TelaNotificacoes extends StatefulWidget {
  const TelaNotificacoes({
    super.key,
    this.notificacaoService = const NotificacaoServiceIndisponivel(),
    this.sincronizarLembretes,
  });

  final NotificacaoService notificacaoService;
  final Future<RelatorioSincronizacaoLembretes> Function()?
  sincronizarLembretes;

  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  StatusPermissaoNotificacao? _status;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _consultarStatus();
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
