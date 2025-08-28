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
        ),

        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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

      // Pantalla de inicio
      home: const SplashScreen(),

      // Rutas nombradas simples (dejamos fuera '/bebidas' para manejarla en onGenerateRoute)
      routes: {
        '/comercios': (_) => const ComerciosPage(),
      },

      // Construcción dinámica de rutas que necesitan argumentos
      onGenerateRoute: (settings) {
        if (settings.name == '/bebidas') {
          final args = (settings.arguments as Map?) ?? {};
          // Admitimos claves 'comercioId' o 'initialComercioId', y el nombre opcional
          final comercioId =
              (args['comercioId'] ?? args['initialComercioId']) as String?;
          final comercioNombre =
              (args['comercioNombre'] ?? args['initialComercioNombre'] ?? '') as String;

          if (comercioId == null || comercioId.isEmpty) {
            // Fallback legible si alguien navega sin argumentos
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Bebidas')),
                body: const Center(
                  child: Text('Falta el comercioId para abrir Bebidas'),
                ),
              ),
            );
          }

          return MaterialPageRoute(
            builder: (_) => BebidasPage(
              initialComercioId: comercioId,
              initialComercioNombre: comercioNombre,
            ),
          );
        }

        // Dejar que otras rutas (si las agregás en el futuro) se resuelvan por defecto
        return null;
      },
    );
  }
}