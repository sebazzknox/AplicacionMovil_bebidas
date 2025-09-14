// lib/admin_gate.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 🔒 Switch local de emergencia (para DEV). Dejalo en `false` en producción.
const bool kAdminOverrideLocal = false;

/* ======================= NUEVA API: adminMode ======================= */

/// Estado global reactivo para la UI (ValueListenableBuilder, etc).
final ValueNotifier<bool> adminMode = ValueNotifier<bool>(kAdminOverrideLocal);

/* ============== COMPATIBILIDAD: API LEGADA (no romper) ============== */

bool kIsAdmin = kAdminOverrideLocal; // espejo de adminMode.value

final StreamController<bool> _adminCtrl = StreamController<bool>.broadcast();
Stream<bool> get adminStream => _adminCtrl.stream;

/* ===================== Watchers y ciclo de vida ===================== */

StreamSubscription<User?>? _authSub;
StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

/// Llamar UNA sola vez en main() **después** de Firebase.initializeApp()
void installAdminGate() {
  // por si se llama dos veces en caliente
  _authSub?.cancel();
  _userDocSub?.cancel();
  _userDocSub = null;

  // emitir el override inicial
  _setAdmin(kAdminOverrideLocal);

  _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
    // siempre cortar el listener previo del doc
    _userDocSub?.cancel();
    _userDocSub = null;

    if (user == null) {
      // Sin sesión → NO escuchamos Firestore y bajamos admin (o dejamos override)
      _setAdmin(kAdminOverrideLocal);
      return;
    }

    // Con sesión → escuchar users/{uid} para ver si es admin
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      final m = doc.data();
      final isAdminFlag = (m?['isAdmin'] == true);
      final isAdminRole = (m?['role']?.toString().toLowerCase() == 'admin');
      _setAdmin(isAdminFlag || isAdminRole || kAdminOverrideLocal);
    }, onError: (_) {
      // ante error leyendo el doc, bajar admin
      _setAdmin(kAdminOverrideLocal);
    });
  }, onError: (_) {
    // ante error de auth, bajar admin
    _setAdmin(kAdminOverrideLocal);
  });
}

/// (opcional) limpiar watchers, útil en tests o hot restart controlado
Future<void> disposeAdminGate() async {
  await _userDocSub?.cancel();
  await _authSub?.cancel();
  _userDocSub = null;
  _authSub = null;
  _setAdmin(kAdminOverrideLocal);
}

/* ============================ Helpers ============================ */

void _setAdmin(bool v) {
  if (adminMode.value != v) {
    adminMode.value = v;
  }
  if (kIsAdmin != v) {
    kIsAdmin = v;
    // emitir para la API legada
    if (!_adminCtrl.isClosed) {
      _adminCtrl.add(v);
    }
  }
}