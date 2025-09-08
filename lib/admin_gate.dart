// lib/admin_gate.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 🔒 Switch local de emergencia (para DEV).
/// Déjalo en false` en producción.
const bool kAdminOverrideLocal = false;

/// ✅ Estado global (NO const). Se actualiza en tiempo real.
bool kIsAdmin = kAdminOverrideLocal;

/// Stream broadcast para quien quiera escuchar cambios.
final StreamController<bool> _adminCtrl =
    StreamController<bool>.broadcast();

Stream<bool> adminStream = _adminCtrl.stream;

/// Lanza el watcher una única vez (llamar en `main()` DESPUÉS de Firebase.initializeApp).
void installAdminGate() {
  // Emitimos el override local por si no hay usuario aún.
  _emit(kAdminOverrideLocal);

  FirebaseAuth.instance
      .authStateChanges()
      .asyncExpand((user) {
        if (user == null) {
          // No logueado → solo el override local manda
          return Stream<bool>.value(kAdminOverrideLocal);
        }
        // Miramos users/{uid} en Firestore
        return FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .map((doc) {
          final m = doc.data() ?? {};
          final byBool = (m['isAdmin'] ?? false) == true;
          final byRole = (m['role'] ?? '').toString().toLowerCase() == 'admin';
          return (byBool || byRole || kAdminOverrideLocal);
        });
      })
      .distinct()
      .listen(_emit, onError: (_) {
        // Ante error, caemos al override local
        _emit(kAdminOverrideLocal);
      });
}

void _emit(bool v) {
  if (kIsAdmin != v) {
    kIsAdmin = v;
    _adminCtrl.add(v);
  }
}