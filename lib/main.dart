import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'home_landing_page.dart';
import 'comercios_page.dart';
import 'bebidas_page.dart';




Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bebidas App',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      // 👉 Dejamos como pantalla inicial la lista de comercios
      home: const HomeLandingPage(),
      routes: {
        '/comercios': (_) => const ComerciosPage(),
      },
    );
  }
}
