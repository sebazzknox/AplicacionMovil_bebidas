import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🌿 Tema minimalista y fresco + mejoras de UI/UX
ThemeData buildMinimalTheme() {
  // (1) Tipografía y jerarquía
  final baseText = GoogleFonts.poppinsTextTheme();
  final textTheme = baseText.copyWith(
    titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: baseText.labelLarge?.copyWith(letterSpacing: .2),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal, // 🌊 toque fresco
      brightness: Brightness.light,
    ),
    textTheme: textTheme,

    scaffoldBackgroundColor: Colors.grey[50], // fondo muy claro

    // (6) AppBar más liviano y con contraste sutil
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.teal.shade800,
      elevation: 0.5,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: Colors.teal.shade800,
      ),
    ),

    // (3) Cards aireadas, con borde suave
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withOpacity(.06)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
    ),

    // (2) Espaciados coherentes en listas y divisores
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      dense: false,
    ),
    dividerTheme: DividerThemeData(
      thickness: 1,
      space: 24,
      color: Colors.black12,
    ),

    // (4) Inputs cómodos y redondeados
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[100],
      hintStyle: const TextStyle(color: Colors.black45),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),

    // (4) Botones consistentes
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.teal.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.teal,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // (5) Chips/badges modernos
    chipTheme: ChipThemeData(
      backgroundColor: Colors.teal.shade50,
      selectedColor: Colors.teal.shade200,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    // (7) BottomSheet / SnackBar / Diálogos prolijos
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 2,
      backgroundColor: Colors.black87,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // (8) NavigationBar / TabBar refinados
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Colors.teal.shade800,
      unselectedLabelColor: Colors.black54,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
      ),
    ),
  );
}

/// 🌙 Versión oscura minimalista (pulida)
ThemeData buildMinimalDarkTheme() {
  // (1) Tipografía consistente
  final baseText = GoogleFonts.poppinsTextTheme();
  final textTheme = baseText.copyWith(
    titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: baseText.labelLarge?.copyWith(letterSpacing: .2),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    ),
    textTheme: textTheme,

    scaffoldBackgroundColor: const Color(0xFF0F0F10),

    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0.5,
      surfaceTintColor: Colors.transparent,
    ),

    // (9) Superficies e inputs con buen contraste en dark
    cardTheme: CardThemeData(
      color: const Color(0xFF151515),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white24.withOpacity(.25)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      hintStyle: const TextStyle(color: Colors.white70),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: Colors.teal.withOpacity(.25),
      selectedColor: Colors.teal.withOpacity(.45),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor: Colors.teal.shade400,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.teal.shade200,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.teal.shade400,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF151515),
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 2,
      backgroundColor: Colors.white70,
      contentTextStyle: const TextStyle(color: Colors.black),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF151515),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorColor: Colors.teal.withOpacity(.25),
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Colors.teal.shade200,
      unselectedLabelColor: Colors.white70,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: Colors.teal.shade300, width: 2),
      ),
    ),
  );
}