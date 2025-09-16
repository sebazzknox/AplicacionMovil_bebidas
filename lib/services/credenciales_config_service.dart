import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio de configuración de credenciales / descuentos
class CredencialesConfigService {
  static final _db = FirebaseFirestore.instance;

  // ---------- Helpers ----------
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Calcula precio aplicando un % de descuento (0..100)
  static double priceWithPct(double base, double pct) {
    final p = pct.clamp(0, 100);
    return (base * (100 - p)) / 100;
  }

  /// Observa el % de descuento vigente para un comercio.
  /// Ruta: /comercios/{comercioId}/config/credenciales
  /// Acepta cualquiera de estos campos numéricos: 'descuentoPct' o 'pct'.
  /// Si no existe, emite 0.0.
  static Stream<double> watchDiscountPctForComercio(String comercioId) {
    return _db
        .collection('comercios')
        .doc(comercioId)
        .collection('config')
        .doc('credenciales')
        .snapshots()
        .map((doc) {
          final data = doc.data();
          final raw = data?['descuentoPct'] ?? data?['pct'];
          final d = _toDouble(raw) ?? 0.0;
          return d.clamp(0, 100).toDouble();
        });
  }

  /// Lee /config/credenciales y devuelve defaults:
  /// { 'CLASICA': 10.0, 'PLUS': 20.0, 'PREMIUM': 30.0 }
  static Future<Map<String, double>> loadGlobalDefaults() async {
    try {
      final doc = await _db.collection('config').doc('credenciales').get();
      final data = doc.data() ?? {};
      final def = (data['beneficiosDefault'] ?? {}) as Map<String, dynamic>;

      double toDoubleSafe(dynamic v) => _toDouble(v) ?? 0.0;

      final result = <String, double>{
        'CLASICA': toDoubleSafe(
          (def['CLASICA'] is Map) ? def['CLASICA']['pct'] : def['CLASICA'],
        ),
        'PLUS': toDoubleSafe(
          (def['PLUS'] is Map) ? def['PLUS']['pct'] : def['PLUS'],
        ),
        'PREMIUM': toDoubleSafe(
          (def['PREMIUM'] is Map) ? def['PREMIUM']['pct'] : def['PREMIUM'],
        ),
      };

      // Limpiar ceros
      result.removeWhere((_, v) => v == 0.0);
      return result;
    } catch (_) {
      // Fallback razonable
      return {'CLASICA': 10.0, 'PLUS': 20.0, 'PREMIUM': 30.0};
    }
  }
}

/// Wrapper para compatibilidad con código existente.
/// Si ya importabas `CredentialService`, no necesitás cambiar nada.
class CredentialService {
  static Stream<double> watchDiscountPctForComercio(String comercioId) =>
      CredencialesConfigService.watchDiscountPctForComercio(comercioId);

  static double priceWithPct(double base, double pct) =>
      CredencialesConfigService.priceWithPct(base, pct);

  static Future<Map<String, double>> loadGlobalDefaults() =>
      CredencialesConfigService.loadGlobalDefaults();
}