import 'package:flutter/material.dart';

class CoresApp {
  CoresApp._();

  // Identidade visual.
  static const Color principal = Color(0xFF6750C8);
  static const Color principalSuave = Color(0xFFEDE7FF);

  // Fundos e superfícies.
  static const Color fundo = Color(0xFFFAF8FF);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color borda = Color(0xFFE2DEEC);

  // Textos.
  static const Color texto = Color(0xFF292735);
  static const Color textoSecundario = Color(0xFF6F6B80);
  static const Color sobrePrincipal = Color(0xFFFFFFFF);

  // Prioridades.
  static const Color prioridadeBaixa = Color(0xFF2D7050);
  static const Color prioridadeBaixaFundo = Color(0xFFE7F3EC);

  static const Color prioridadeMedia = Color(0xFF805900);
  static const Color prioridadeMediaFundo = Color(0xFFFFF3CD);

  static const Color prioridadeAlta = Color(0xFFB3261E);
  static const Color prioridadeAltaFundo = Color(0xFFFCE8E6);

  // Situações das tarefas.
  static const Color concluida = Color(0xFF2D7050);
  static const Color concluidaFundo = Color(0xFFE7F3EC);

  static const Color pendente = Color(0xFF625D71);
  static const Color pendenteFundo = Color(0xFFF0EDF5);

  static const Color pausada = principal;
  static const Color pausadaFundo = principalSuave;

  static const Color atrasada = Color(0xFFB3261E);
  static const Color atrasadaFundo = Color(0xFFFCE8E6);

  // Erros de formulário e operações.
  static const Color erro = Color(0xFFB3261E);
}