// lib/services/credential_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CredentialService {
  CredentialService._();
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Devuelve el % de descuento que le corresponde al usuario actual
  /// para el comercio/mayorista [comercioId].
  /// - Si el comercio tiene su propio `beneficios.<TIER>.pct`, usa ese.
  /// - Si no, usa `config/credenciales.beneficiosDefault.<TIER>.pct`.
  /// - Si el usuario no tiene credencial activa/valida → 0.
  static Future<double> discountPctForComercio(String comercioId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    // 1) Leer credencial del usuario
    final credSnap = await _db.collection('credenciales').doc(uid).get();
    if (!credSnap.exists) return 0;
    final cred = credSnap.data()!;
    final estado = (cred['estado'] ?? 'activa').toString();
    if (estado != 'activa') return 0;

    final expTs = cred['expira'];
    if (expTs is Timestamp && expTs.toDate().isBefore(DateTime.now())) {
      return 0; // expirada
    }

    final tier = (cred['tier'] ?? 'CLASICA').toString().toUpperCase();

    // 2) Leer beneficios propios del comercio
    final comSnap = await _db.collection('comercios').doc(comercioId).get();
    final com = comSnap.data() ?? {};
    final acepta = (com['aceptaCredencial'] ?? false) == true;
    if (!acepta) return 0;

    double? pct;

    final beneficios = (com['beneficios'] as Map<String, dynamic>?) ?? {};
    final tierMap = beneficios[tier] as Map<String, dynamic>?;
    pct = (tierMap?['pct'] as num?)?.toDouble();

    // 3) Fallback a defaults globales (config/credenciales)
    if (pct == null) {
      final cfg = await _db.collection('config').doc('credenciales').get();
      final data = cfg.data() ?? {};
      final def = (data['beneficiosDefault'] as Map<String, dynamic>?) ?? {};
      final tierDef = def[tier] as Map<String, dynamic>?;
      pct = (tierDef?['pct'] as num?)?.toDouble();
    }

    return pct ?? 0;
  }

  /// Stream que reacciona a cambios (credencial/comercio/config) y emite el % actual.
  static Stream<double> watchDiscountPctForComercio(String comercioId) {
    final controller = StreamController<double>.broadcast();
    final subs = <StreamSubscription>[];

    Future<void> emit() async {
      try {
        final pct = await discountPctForComercio(comercioId);
        if (!controller.isClosed) controller.add(pct);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    // Suscripciones relevantes
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      subs.add(_db.collection('credenciales').doc(uid).snapshots().listen((_) => emit()));
    }
    subs.add(_db.collection('comercios').doc(comercioId).snapshots().listen((_) => emit()));
    subs.add(_db.collection('config').doc('credenciales').snapshots().listen((_) => emit()));

    controller.onListen = emit; // primera emisión
    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
      await controller.close();
    };

    return controller.stream;
  }

  /// Utilidad para calcular precio con descuento (%).
  static double priceWithPct(double precio, double pct) {
    if (pct <= 0) return precio;
    return (precio * (100 - pct)) / 100.0;
  }

  /// Si tenés precio promo y pct de credencial, devuelve el MÁS BARATO.
  static double betterOfPromoOrCredential({
    required double precioBase,
    double? precioPromo,
    required double pctCred,
  }) {
    final withCred = priceWithPct(precioBase, pctCred);
    if (precioPromo == null) return withCred;
    return withCred < precioPromo ? withCred : precioPromo;
  }
}