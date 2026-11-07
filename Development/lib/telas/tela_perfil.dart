import 'package:flutter/material.dart';

import '../services/configuracoes_service.dart';
import '../services/notificacao_service.dart';
import '../tema/cores.dart';
import 'tela_notificacoes.dart';

/// Perfil local e acesso às configurações.
class TelaPerfil extends StatefulWidget {
  const TelaPerfil({
    super.key,
    required this.configuracoesService,
    this.notificacaoService = const NotificacaoServiceIndisponivel(),
    this.sincronizarLembretes,
  });

  final ConfiguracoesService configuracoesService;
  final NotificacaoService notificacaoService;
  final Future<RelatorioSincronizacaoLembretes> Function()?
  sincronizarLembretes;

  @override
  State<TelaPerfil> createState() => _TelaPerfilState();
}

class _TelaPerfilState extends State<TelaPerfil> {
  late final TextEditingController _nomeController;
  late final FocusNode _nomeFocus;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: widget.configuracoesService.configuracoes.nomeExibicao ?? '',
    );
    _nomeFocus = FocusNode();
    widget.configuracoesService.addListener(_sincronizarNomePersistido);
  }

  @override
  void didUpdateWidget(covariant TelaPerfil oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuracoesService != widget.configuracoesService) {
      oldWidget.configuracoesService.removeListener(_sincronizarNomePersistido);
      widget.configuracoesService.addListener(_sincronizarNomePersistido);
      _sincronizarNomePersistido();
    }
  }

  @override
  void dispose() {
    widget.configuracoesService.removeListener(_sincronizarNomePersistido);
    _nomeController.dispose();
    _nomeFocus.dispose();
    super.dispose();
  }

  void _sincronizarNomePersistido() {
    if (!mounted) return;
    final nome = widget.configuracoesService.configuracoes.nomeExibicao ?? '';
    if (!_nomeFocus.hasFocus && _nomeController.text != nome) {
      _nomeController.value = TextEditingValue(
        text: nome,
        selection: TextSelection.collapsed(offset: nome.length),
      );
    }
    setState(() {});
  }

  Future<void> _salvarNome([String? valor]) async {
    if (_salvando) return;
    setState(() => _salvando = true);

    try {
      await widget.configuracoesService.salvarNomeExibicao(
        valor ?? _nomeController.text,
      );
      if (!mounted) return;

      final nomeSalvo =
          widget.configuracoesService.configuracoes.nomeExibicao ?? '';
      _nomeController.value = TextEditingValue(
        text: nomeSalvo,
        selection: TextSelection.collapsed(offset: nomeSalvo.length),
      );
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nomeSalvo.isEmpty ? 'Nome removido.' : 'Perfil salvo.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar o perfil. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _abrirNotificacoes() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TelaNotificacoes(
          notificacaoService: widget.notificacaoService,
          sincronizarLembretes: widget.sincronizarLembretes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = widget.configuracoesService.configuracoes.nomeExibicao;

    return SafeArea(
      top: false,
      child: ListView(
        key: const PageStorageKey<String>('perfil'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: CoresApp.principalSuave,
                    foregroundColor: CoresApp.principal,
                    child: Icon(Icons.person_rounded, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome ?? 'Seu perfil',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Salvo somente neste dispositivo',
                          style: TextStyle(color: CoresApp.textoSecundario),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Personalização',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('campo_nome_exibicao'),
            controller: _nomeController,
            focusNode: _nomeFocus,
            enabled: !_salvando,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _salvarNome(),
            decoration: const InputDecoration(
              labelText: 'Nome de exibição',
              hintText: 'Como você quer ser chamado?',
              helperText: 'Este nome aparece na saudação da tela Hoje.',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('salvar_perfil'),
            onPressed: _salvando ? null : _salvarNome,
            icon: _salvando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_salvando ? 'Salvando...' : 'Salvar nome'),
          ),
          if (nome != null) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              key: const Key('remover_nome'),
              onPressed: _salvando ? null : () => _salvarNome(''),
              icon: const Icon(Icons.person_off_outlined),
              label: const Text('Remover nome'),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Preferências',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              key: const Key('abrir_notificacoes_perfil'),
              onTap: _abrirNotificacoes,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              leading: const CircleAvatar(
                backgroundColor: CoresApp.principalSuave,
                foregroundColor: CoresApp.principal,
                child: Icon(Icons.notifications_none_rounded),
              ),
              title: const Text(
                'Notificações',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Acesse as configurações de notificações'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
