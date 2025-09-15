import 'package:cloud_firestore/cloud_firestore.dart';

class CredencialesConfigService {
  static final _db = FirebaseFirestore.instance;

  /// Lee /config/credenciales y devuelve { 'CLASICA': 10.0, 'PLUS': 20.0, 'PREMIUM': 30.0 }
  static Future<Map<String, double>> loadGlobalDefaults() async {
    try {
      final doc = await _db.collection('config').doc('credenciales').get();
      final data = doc.data() ?? {};
      final def = (data['beneficiosDefault'] ?? {}) as Map<String, dynamic>;

      double _num(dynamic v) =>
          (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

      return <String, double>{
        'CLASICA': _num((def['CLASICA'] is Map) ? def['CLASICA']['pct'] : def['CLASICA']),
        'PLUS'   : _num((def['PLUS']    is Map) ? def['PLUS']['pct']    : def['PLUS']),
        'PREMIUM': _num((def['PREMIUM'] is Map) ? def['PREMIUM']['pct'] : def['PREMIUM']),
      }..removeWhere((k, v) => v == 0.0);
    } catch (_) {
      // fallback
      return {'CLASICA': 10, 'PLUS': 20, 'PREMIUM': 30};
    }
  }
}