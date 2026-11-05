import 'package:flutter/material.dart';

import 'cores.dart';

class TemaApp {
  TemaApp._();

  static final ThemeData claro = ThemeData(
    useMaterial3: true,

    colorScheme: ColorScheme.fromSeed(
      seedColor: CoresApp.principal,
      brightness: Brightness.light,
    ).copyWith(
      primary: CoresApp.principal,
      onPrimary: CoresApp.sobrePrincipal,
      primaryContainer: CoresApp.principalSuave,
      onPrimaryContainer: CoresApp.principal,
      surface: CoresApp.superficie,
      onSurface: CoresApp.texto,
      onSurfaceVariant: CoresApp.textoSecundario,
      outlineVariant: CoresApp.borda,
      error: CoresApp.erro,
    ),

    scaffoldBackgroundColor: CoresApp.fundo,

    // Barra superior das páginas.
    appBarTheme: const AppBarTheme(
      backgroundColor: CoresApp.fundo,
      foregroundColor: CoresApp.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),

    // Estilos que poderão ser usados com Theme.of(context).textTheme.
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: CoresApp.texto,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: CoresApp.texto,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: CoresApp.texto,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: CoresApp.texto,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: CoresApp.texto,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: CoresApp.textoSecundario,
      ),
    ),

    // Padrão dos botões principais.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CoresApp.principal,
        foregroundColor: CoresApp.sobrePrincipal,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 14,
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
    ),

    // Padrão dos campos de formulário.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CoresApp.superficie,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CoresApp.borda),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: CoresApp.principal,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CoresApp.erro),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: CoresApp.erro,
          width: 2,
        ),
      ),
    ),

    // Padrão dos cartões.
    cardTheme: CardThemeData(
      color: CoresApp.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: CoresApp.borda),
      ),
    ),

    // Padrão da navegação inferior.
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: CoresApp.superficie,
      indicatorColor: CoresApp.principalSuave,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CoresApp.principal,
      linearTrackColor: CoresApp.principalSuave,
    ),
  );
}