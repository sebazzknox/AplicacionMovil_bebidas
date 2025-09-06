// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_state.dart';
import 'splash_screen.dart';
import 'comercios_page.dart';
import 'bebidas_page.dart';
import 'admin_new_promo_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Fechas localizadas
  await initializeDateFormatting('es_AR', null);

  // Firestore offline cache
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);

  // ⚙️ Modo admin (cambiar a true solo cuando quieras permisos)
  adminMode.value = false;

  runApp( AdminState(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Tema base con Poppins
    final light = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF6F4BC7),
      textTheme: GoogleFonts.poppinsTextTheme(),
    );
    final dark = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF6F4BC7),
      brightness: Brightness.dark,
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bebidas App',

      theme: light,
      darkTheme: dark,
      themeMode: ThemeMode.light,

      // Idioma
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Pantalla inicial
      home: const SplashScreen(),

      // Rutas simples
      routes: {
        '/comercios': (_) => const ComerciosPage(),
        '/admin/nueva-promo': (_) => const AdminNewPromoPage(),
      },

      // Rutas con argumentos
      onGenerateRoute: (settings) {
        if (settings.name == '/bebidas') {
          final args = (settings.arguments as Map?) ?? {};
          final comercioId =
              (args['comercioId'] ?? args['initialComercioId']) as String?;
          final comercioNombre = (args['comercioNombre'] ??
                  args['initialComercioNombre'] ??
                  '') as String;

          if (comercioId == null || comercioId.isEmpty) {
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
        return null;
      },
    );
  }
}