import 'package:flutter/material.dart';
import '../tema/cores.dart';

/// Variações visuais do botão reutilizável do FlowTask.
enum TipoBotao {
  /// Fundo roxo principal (`CoresApp.principal`) e texto branco (`CoresApp.sobrePrincipal`).
  primario,

  /// Fundo suave (`CoresApp.pendenteFundo`) e texto secundário (`CoresApp.pendente`).
  secundario,

  /// Fundo de superfície (`CoresApp.superficie`) com borda (`CoresApp.borda`) e texto roxo (`CoresApp.principal`).
  contorno,
}

/// Botão reutilizável do aplicativo seguindo o Design System do FlowTask.
class Botao extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final IconData? icone;
  final TipoBotao tipo;
  final bool larguraTotal;

  const Botao({
    super.key,
    required this.texto,
    this.onPressed,
    this.icone,
    this.tipo = TipoBotao.primario,
    this.larguraTotal = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color corFundo;
    final Color corTexto;
    final BorderSide borda;

    switch (tipo) {
      case TipoBotao.primario:
        corFundo = CoresApp.principal;
        corTexto = CoresApp.sobrePrincipal;
        borda = BorderSide.none;
      case TipoBotao.secundario:
        corFundo = CoresApp.pendenteFundo;
        corTexto = CoresApp.pendente;
        borda = BorderSide.none;
      case TipoBotao.contorno:
        corFundo = CoresApp.superficie;
        corTexto = CoresApp.principal;
        borda = const BorderSide(color: CoresApp.borda, width: 1.2);
    }

    final estilo = ElevatedButton.styleFrom(
      backgroundColor: corFundo,
      foregroundColor: corTexto,
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: borda,
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );

    final Widget botao = icone != null
        ? ElevatedButton.icon(
            onPressed: onPressed,
            style: estilo,
            icon: Icon(icone, size: 22, color: corTexto),
            label: Text(texto),
          )
        : ElevatedButton(
            onPressed: onPressed,
            style: estilo,
            child: Text(texto),
          );

    if (larguraTotal) {
      return SizedBox(
        width: double.infinity,
        child: botao,
      );
    }

    return botao;
  }
}
