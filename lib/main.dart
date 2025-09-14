// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

// ⬇️ Traemos SOLO lo que usamos (evita choques de nombres)
import 'admin_gate.dart' show installAdminGate, adminStream;
import 'admin_state.dart' show adminMode, AdminState;
import 'auth/auth_gate.dart';

import 'splash_screen.dart';
import 'comercios_page.dart';
import 'bebidas_page.dart';
import 'admin_new_promo_page.dart';
import 'notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await Notifications.init();
  await initializeDateFormatting('es_AR', null);

  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);

  // 🔒 Arranca el watcher que mira users/{uid} y emite si es admin.
  installAdminGate();

  // ⬅️ Sincronizamos el stream con el ValueNotifier que usa la UI
  adminStream.listen((isAdmin) {
    adminMode.value = isAdmin;
    // Debug útil para verificar que entra:
    // ignore: avoid_print
    print('[adminGate] isAdmin=$isAdmin  uid=${FirebaseFirestore.instance.app.name}');
  });

  runApp(const _Root());
}

class _Root extends StatelessWidget {
  const _Root({super.key});

  @override
  Widget build(BuildContext context) {
    // Envolvemos toda la app con AdminState por si en algún lado usan
    // AdminState.isAdmin(context). Igual la UI también escucha adminMode.
    return AdminState(
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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

      // Gate: si no hay sesión -> AuthPage; si hay -> Splash + flujo normal
      home: AuthGate(home: const SplashScreen()),

      routes: {
        '/comercios': (_) => const ComerciosPage(),
        '/admin/nueva-promo': (_) => const AdminNewPromoPage(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == '/bebidas') {
          final args = (settings.arguments as Map?) ?? {};
          final comercioId =
              (args['comercioId'] ?? args['initialComercioId']) as String?;
          final comercioNombre =
              (args['comercioNombre'] ??
                      args['initialComercioNombre'] ??
                      '') as String;

          if (comercioId == null || comercioId.isEmpty) {
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Bebidas')),
                body:
                    const Center(child: Text('Falta el comercioId para abrir Bebidas')),
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