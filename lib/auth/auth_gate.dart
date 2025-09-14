import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_page.dart';

class AuthGate extends StatelessWidget {
  final Widget home;
  const AuthGate({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) return const AuthPage(); // ⬅️ muestra login/registro
        return home; // ⬅️ ya logueado -> Home
      },
    );
  }
}