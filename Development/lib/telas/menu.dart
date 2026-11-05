import 'package:flutter/material.dart';
import '../tema/cores.dart';
import 'tela_calendario.dart';
import 'tela_foco.dart';
import 'tela_hoje.dart';
import 'tela_notificacoes.dart';
import 'tela_perfil.dart';
import 'tela_tarefa.dart';

/// Item de navegação do menu expansivo (Drawer).
class _ItemMenu {
  final String titulo;
  final IconData icone;
  final Widget tela;

  const _ItemMenu({
    required this.titulo,
    required this.icone,
    required this.tela,
  });
}

/// Navegação principal entre Hoje, Calendário, Foco, Notificações e Perfil
/// utilizando o menu expansivo lateral (ícone de 3 riscos no canto superior esquerdo).
class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  int _indiceSelecionado = 0;

  static const List<_ItemMenu> _itens = [
    _ItemMenu(
      titulo: 'Hoje',
      icone: Icons.checklist_rounded,
      tela: TelaHoje(),
    ),
    _ItemMenu(
      titulo: 'Calendário',
      icone: Icons.calendar_today_outlined,
      tela: TelaCalendario(),
    ),
    _ItemMenu(
      titulo: 'Foco',
      icone: Icons.timer_outlined,
      tela: TelaFoco(),
    ),
    _ItemMenu(
      titulo: 'Notificações',
      icone: Icons.notifications_none_rounded,
      tela: TelaNotificacoes(),
    ),
    _ItemMenu(
      titulo: 'Perfil',
      icone: Icons.person_outline_rounded,
      tela: TelaPerfil(),
    ),
  ];

  void _selecionarItem(int indice) {
    setState(() {
      _indiceSelecionado = indice;
    });
    Navigator.of(context).pop(); // Fecha o menu expansivo após selecionar
  }

  void _abrirNovaTarefa() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TelaTarefa(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemAtual = _itens[_indiceSelecionado];

    return Scaffold(
      backgroundColor: CoresApp.fundo,
      appBar: AppBar(
        backgroundColor: CoresApp.fundo,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Ícone de 3 riscos (hambúrguer) no canto superior esquerdo
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: CoresApp.texto,
              size: 28,
            ),
            tooltip: 'Abrir menu de navegação',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          itemAtual.titulo,
          style: const TextStyle(
            color: CoresApp.texto,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _indiceSelecionado = 3; // Aba de Notificações
                });
              },
              style: IconButton.styleFrom(
                backgroundColor: CoresApp.principalSuave,
                shape: const CircleBorder(),
              ),
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: CoresApp.principal,
              ),
              tooltip: 'Notificações',
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: CoresApp.superficie,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabeçalho do Menu Expansivo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CoresApp.principalSuave,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: CoresApp.principal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: CoresApp.sobrePrincipal,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FlowTask',
                              style: TextStyle(
                                color: CoresApp.texto,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Planejamento e Foco',
                              style: TextStyle(
                                color: CoresApp.textoSecundario,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Botão rápido de Nova Tarefa
                FilledButton.icon(
                  onPressed: _abrirNovaTarefa,
                  style: FilledButton.styleFrom(
                    backgroundColor: CoresApp.principal,
                    foregroundColor: CoresApp.sobrePrincipal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Adicionar tarefa',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: CoresApp.borda),
                const SizedBox(height: 12),

                // Lista de opções de navegação
                Expanded(
                  child: ListView.separated(
                    itemCount: _itens.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = _itens[index];
                      final selecionado = index == _indiceSelecionado;

                      return Material(
                        color: selecionado
                            ? CoresApp.principalSuave
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _selecionarItem(index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icone,
                                  color: selecionado
                                      ? CoresApp.principal
                                      : CoresApp.textoSecundario,
                                  size: 24,
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  item.titulo,
                                  style: TextStyle(
                                    color: selecionado
                                        ? CoresApp.principal
                                        : CoresApp.texto,
                                    fontSize: 15,
                                    fontWeight: selecionado
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _indiceSelecionado,
        children: _itens.map((item) => item.tela).toList(),
      ),
    );
  }
}
