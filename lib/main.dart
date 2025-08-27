import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'comercios_page.dart';
import 'bebidas_page.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('es_AR', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseText = GoogleFonts.poppinsTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bebidas App',

      // Idioma
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Tema
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        textTheme: baseText,

        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
          // si tu SDK lo permite, después podemos volver a agregar shape
        ),

        // <- aquí el cambio: CardThemeData en lugar de CardTheme
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // si tu SDK lo soporta, luego podemos sumar: margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        ),

        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),

      // Inicio
      home: const SplashScreen(),
      routes: {
        '/comercios': (_) => const ComerciosPage(),
        '/bebidas': (_) => const BebidasPage(),
      },
    );
  }
}