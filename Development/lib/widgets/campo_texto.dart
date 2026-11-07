import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de formulário reutilizável no padrão visual do FlowTask.
///
/// Usa [TextFormField] diretamente para integrar validação, foco, teclado e
/// mensagens de erro ao [InputDecorationTheme] definido por [ThemeData].
class CampoTexto extends StatelessWidget {
  final String rotulo;
  final String? dica;
  final TextEditingController? controller;
  final String? valorInicial;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final String? textoErro;
  final FocusNode? focusNode;
  final bool habilitado;
  final bool somenteLeitura;
  final bool autofocus;
  final bool ocultarTexto;
  final int minLinhas;
  final int maxLinhas;
  final int? maxCaracteres;
  final IconData? iconePrefixo;
  final IconData? iconeSufixo;
  final TextInputType? tipoTeclado;
  final TextInputAction? acaoTeclado;
  final TextCapitalization capitalizacao;
  final AutovalidateMode? modoAutovalidacao;
  final List<TextInputFormatter>? formatadores;

  const CampoTexto({
    super.key,
    required this.rotulo,
    this.dica,
    this.controller,
    this.valorInicial,
    this.onChanged,
    this.onTap,
    this.onEditingComplete,
    this.onSubmitted,
    this.validator,
    this.textoErro,
    this.focusNode,
    this.habilitado = true,
    this.somenteLeitura = false,
    this.autofocus = false,
    this.ocultarTexto = false,
    this.minLinhas = 1,
    this.maxLinhas = 1,
    this.maxCaracteres,
    this.iconePrefixo,
    this.iconeSufixo,
    this.tipoTeclado,
    this.acaoTeclado,
    this.capitalizacao = TextCapitalization.sentences,
    this.modoAutovalidacao,
    this.formatadores,
  }) : assert(
         controller == null || valorInicial == null,
         'controller e valorInicial não podem ser usados ao mesmo tempo.',
       ),
       assert(minLinhas > 0),
       assert(maxLinhas >= minLinhas),
       assert(!ocultarTexto || maxLinhas == 1);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final deslocamentoHorizontal = iconePrefixo == null ? 16.0 : 48.0;

    return Semantics(
      textField: true,
      label: rotulo,
      child: Stack(
        children: [
          TextFormField(
            controller: controller,
            initialValue: controller == null ? valorInicial : null,
            focusNode: focusNode,
            enabled: habilitado,
            readOnly: somenteLeitura,
            autofocus: autofocus,
            obscureText: ocultarTexto,
            minLines: minLinhas,
            maxLines: maxLinhas,
            maxLength: maxCaracteres,
            keyboardType: tipoTeclado,
            textInputAction: acaoTeclado,
            textCapitalization: capitalizacao,
            inputFormatters: formatadores,
            autovalidateMode: modoAutovalidacao,
            validator: validator,
            onChanged: onChanged,
            onTap: onTap,
            onEditingComplete: onEditingComplete,
            onFieldSubmitted: onSubmitted,
            cursorColor: tema.colorScheme.primary,
            style: tema.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: dica,
              errorText: textoErro,
              contentPadding: EdgeInsets.fromLTRB(
                deslocamentoHorizontal,
                30,
                iconeSufixo == null ? 16 : 48,
                12,
              ),
              prefixIcon: iconePrefixo == null ? null : Icon(iconePrefixo),
              suffixIcon: iconeSufixo == null ? null : Icon(iconeSufixo),
            ),
          ),
          Positioned(
            top: 9,
            left: deslocamentoHorizontal,
            right: iconeSufixo == null ? 12 : 44,
            child: IgnorePointer(
              child: Text(
                rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.inputDecorationTheme.labelStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
