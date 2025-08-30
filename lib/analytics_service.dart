// lib/analytics_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Servicio simple para registrar eventos de uso dentro de Firestore.
/// Colección: `events`
/// Cada doc: { type, at, uid, props... }
class Analytics {
  Analytics._();
  static final Analytics I = Analytics._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Guarda un evento.
  /// [type] ejemplos: 'search', 'toggle_near', 'view_commerce', 'tap_call'
  /// [comercioId] si aplica, id del comercio.
  /// [props] mapa adicional (ej: {'query':'leo', 'abierto':true})
  Future<void> log(
    String type, {
    String? comercioId,
    Map<String, dynamic>? props,
  }) async {
    try {
      // asegurar sesión (anónima si hace falta)
      await _ensureSignedIn();

      final uid = _auth.currentUser?.uid;
      final data = <String, dynamic>{
        'type': type,
        'at': FieldValue.serverTimestamp(),
        'uid': uid,
        if (comercioId != null) 'comercioId': comercioId,
        if (props != null) ...props,
      };

      await _db.collection('events').add(data);
      if (kDebugMode) {
        // ignore: avoid_print
        print('[analytics] $type ${comercioId ?? ''} ${props ?? {}}');
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[analytics][ERROR] $e');
      }
    }
  }

  /// Devuelve un stream con conteo de eventos por `type` en los últimos [days] días.
  Stream<Map<String, int>> countByType({int days = 30}) {
    final from = DateTime.now().subtract(Duration(days: days));
    return _db
        .collection('events')
        .where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('at', descending: true)
        .snapshots()
        .map((snap) {
      final map = <String, int>{};
      for (final d in snap.docs) {
        final m = d.data();
        final t = (m['type'] ?? '').toString();
        if (t.isEmpty) continue;
        map[t] = (map[t] ?? 0) + 1;
      }
      return map;
    });
  }

  /// Conteo por comercio en los últimos [days] días.
  Stream<Map<String, int>> countByComercio({int days = 30}) {
    final from = DateTime.now().subtract(Duration(days: days));
    return _db
        .collection('events')
        .where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('comercioId', isNull: false)
        .orderBy('at', descending: true)
        .snapshots()
        .map((snap) {
      final map = <String, int>{};
      for (final d in snap.docs) {
        final m = d.data();
        final id = (m['comercioId'] ?? '').toString();
        if (id.isEmpty) continue;
        map[id] = (map[id] ?? 0) + 1;
      }
      return map;
    });
  }

  /// Asegura sesión (habilita Anonymous si no hay).
  static Future<void> _ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }
}