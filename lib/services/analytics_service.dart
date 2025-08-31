import 'package:cloud_firestore/cloud_firestore.dart';

class AppAnalytics {
  static final _col =
      FirebaseFirestore.instance.collection('analytics_events');

  /// Envia un evento genérico
  static Future<void> log({
    required String type,              // app_open | interaction | business_view
    Map<String, dynamic>? data,        // payload opcional
  }) async {
    await _col.add({
      'type': type,
      'ts': FieldValue.serverTimestamp(),
      if (data != null) 'data': data,
    });
  }

  /// Helpers cortos
  static Future<void> appOpen() =>
      log(type: 'app_open');

  static Future<void> interaction(String name, {Map<String, dynamic>? extra}) =>
      log(type: 'interaction', data: {'name': name, ...?extra});

  static Future<void> businessView(String comercioId) =>
      log(type: 'business_view', data: {'comercioId': comercioId});
}