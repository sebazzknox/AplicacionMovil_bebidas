// lib/app_auth.dart
import 'package:firebase_auth/firebase_auth.dart';

/// Admin = hay un usuario logueado.
bool get kIsAdmin => FirebaseAuth.instance.currentUser != null;

/// Inicia sesión de admin con email y password.
Future<void> signInAdmin(String email, String password) async {
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email.trim(),
    password: password.trim(),
  );
}

/// Cierra la sesión de admin.
Future<void> signOutAdmin() async {
  await FirebaseAuth.instance.signOut();


  
}
