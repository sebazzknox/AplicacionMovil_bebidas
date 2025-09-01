import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_new_promo_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'comercios_page.dart';
import 'bebidas_page.dart';
import 'splash_screen.dart';
import 'theme.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // (si usás fechas localizadas)
  await initializeDateFormatting('es_AR', null);

  // 🔒 Habilitar caché/offline de Firestore
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);

  runApp(const MyApp());
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Lo mantenemos por si lo usás en otros lados
    final baseText = GoogleFonts.poppinsTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bebidas App',

      // 👇 Usa los temas centralizados de theme.dart (dejado como lo tenías)
      // theme: buildLightTheme(),
      // darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      // theme: buildGraffitiTheme(),

      // Idioma
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Pantalla de inicio
      home: const SplashScreen(),

      // Rutas nombradas simples
      routes: {
        '/comercios': (_) => const ComerciosPage(),
        // 👇 Nueva ruta para crear/cargar una promo desde el admin
        '/admin/nueva-promo': (_) => const AdminNewPromoPage(),
      },

      // Construcción dinámica de rutas que necesitan argumentos
      onGenerateRoute: (settings) {
        if (settings.name == '/bebidas') {
          final args = (settings.arguments as Map?) ?? {};
          final comercioId =
              (args['comercioId'] ?? args['initialComercioId']) as String?;
          final comercioNombre =
              (args['comercioNombre'] ?? args['initialComercioNombre'] ?? '') as String;

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

        // Dejar que otras rutas (si las agregás en el futuro) se resuelvan por defecto
        return null;
      },
    );
  }
}