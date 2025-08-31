// lib/analytics.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Analytics {
  static final _col = FirebaseFirestore.instance.collection('analytics_events');

  static Future<void> _ensureUser() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  }

  /// Registra un evento genérico
  static Future<void> logEvent(String type, {Map<String, dynamic>? data}) async {
    await _ensureUser();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _col.add({
      'type': type,                // 'app_open' | 'interaction' | 'business_view'
      'data': data ?? {},
      'uid': uid,
      'ts': FieldValue.serverTimestamp(),
      'day': DateTime.now().toUtc().toIso8601String().substring(0, 10), // YYYY-MM-DD
    });
  }

  static Future<void> logAppOpen() => logEvent('app_open');

  static Future<void> logInteraction(String action, {String? comercioId}) =>
      logEvent('interaction', {'action': action, if (comercioId != null) 'comercioId': comercioId});

  static Future<void> logBusinessView(String comercioId) =>
      logEvent('business_view', {'comercioId': comercioId});
}