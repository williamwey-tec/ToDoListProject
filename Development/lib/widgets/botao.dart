import 'package:flutter/material.dart';

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
  final bool carregando;
  final String? textoCarregando;

  const Botao({
    super.key,
    required this.texto,
    this.onPressed,
    this.icone,
    this.tipo = TipoBotao.primario,
    this.larguraTotal = true,
    this.carregando = false,
    this.textoCarregando,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final bool disponivel = onPressed != null && !carregando;
    final VoidCallback? callbackBotao = carregando ? () {} : onPressed;
    final Color corFundo;
    final Color corTexto;
    final BorderSide borda;

    switch (tipo) {
      case TipoBotao.primario:
        corFundo = cores.primary;
        corTexto = cores.onPrimary;
        borda = BorderSide.none;
      case TipoBotao.secundario:
        corFundo = cores.primaryContainer;
        corTexto = cores.onPrimaryContainer;
        borda = BorderSide.none;
      case TipoBotao.contorno:
        corFundo = cores.surface;
        corTexto = cores.primary;
        borda = BorderSide(color: cores.outlineVariant, width: 1.2);
    }

    final estilo = ElevatedButton.styleFrom(
      backgroundColor: corFundo,
      foregroundColor: corTexto,
      disabledBackgroundColor: tema.elevatedButtonTheme.style?.backgroundColor
          ?.resolve(const {WidgetState.disabled}),
      disabledForegroundColor: tema.elevatedButtonTheme.style?.foregroundColor
          ?.resolve(const {WidgetState.disabled}),
      minimumSize: const Size(48, 52),
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: borda,
      ),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );

    final Widget conteudo = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: carregando
          ? Wrap(
              key: const ValueKey('carregando'),
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: corTexto,
                  ),
                ),
                Text(textoCarregando ?? texto, textAlign: TextAlign.center),
              ],
            )
          : Wrap(
              key: const ValueKey('normal'),
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                if (icone != null) Icon(icone, size: 22),
                Text(texto, textAlign: TextAlign.center),
              ],
            ),
    );

    final Widget botao = Semantics(
      button: true,
      enabled: disponivel,
      liveRegion: carregando,
      label: carregando ? (textoCarregando ?? 'Carregando $texto') : texto,
      onTap: disponivel ? onPressed : null,
      excludeSemantics: true,
      child: ElevatedButton(
        onPressed: callbackBotao,
        style: estilo,
        child: conteudo,
      ),
    );

    if (larguraTotal) {
      return SizedBox(width: double.infinity, child: botao);
    }

    return botao;
  }
}
