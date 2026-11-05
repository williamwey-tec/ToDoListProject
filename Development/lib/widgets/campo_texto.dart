import 'package:flutter/material.dart';
import '../tema/cores.dart';

/// Campo de formulário reutilizável no padrão visual do FlowTask
/// (container branco arredondado com rótulo superior interno e ícone opcional).
class CampoTexto extends StatelessWidget {
  final String rotulo;
  final String? dica;
  final TextEditingController? controller;
  final String? valorInicial;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool somenteLeitura;
  final int maxLinhas;
  final IconData? iconeSufixo;
  final TextInputType? tipoTeclado;

  const CampoTexto({
    super.key,
    required this.rotulo,
    this.dica,
    this.controller,
    this.valorInicial,
    this.onChanged,
    this.onTap,
    this.somenteLeitura = false,
    this.maxLinhas = 1,
    this.iconeSufixo,
    this.tipoTeclado,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: somenteLeitura ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: CoresApp.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CoresApp.borda, width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: maxLinhas > 1
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rotulo,
                    style: const TextStyle(
                      color: CoresApp.textoSecundario,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: controller,
                    initialValue: controller == null ? valorInicial : null,
                    onChanged: onChanged,
                    onTap: onTap,
                    readOnly: somenteLeitura,
                    maxLines: maxLinhas,
                    keyboardType: tipoTeclado,
                    cursorColor: CoresApp.principal,
                    style: const TextStyle(
                      color: CoresApp.texto,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: dica,
                      hintStyle: const TextStyle(
                        color: CoresApp.textoSecundario,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (iconeSufixo != null) ...[
              const SizedBox(width: 8),
              Icon(
                iconeSufixo,
                color: CoresApp.textoSecundario,
                size: 22,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
