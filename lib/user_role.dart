import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum AppRole { admin, merchant, customer, unknown }

AppRole roleFromString(String? s) {
  switch (s) {
    case 'admin': return AppRole.admin;
    case 'merchant': return AppRole.merchant;
    case 'customer': return AppRole.customer;
    default: return AppRole.unknown;
  }
}

class CurrentUserRole extends ChangeNotifier {
  final _users = FirebaseFirestore.instance.collection('users');
  AppRole _role = AppRole.unknown;
  String? _comercioId;

  AppRole get role => _role;
  String? get comercioId => _comercioId;

  Stream<void> bind(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      final data = snap.data();
      _role = roleFromString(data?['role'] as String?);
      _comercioId = data?['comercioId'] as String?;
      notifyListeners();
    });
  }

  Future<void> seedIfMissing(String uid) async {
    final ref = _users.doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}