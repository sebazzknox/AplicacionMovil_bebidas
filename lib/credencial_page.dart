// lib/credencial_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CredencialPage extends StatefulWidget {
  const CredencialPage({super.key});

  @override
  State<CredencialPage> createState() => _CredencialPageState();
}

class _CredencialPageState extends State<CredencialPage> {
  User? get _user => FirebaseAuth.instance.currentUser;

  // Para invalidar el QR periódicamente
  int _qrSalt = DateTime.now().millisecondsSinceEpoch;
  Timer? _qrTimer;

  @override
  void initState() {
    super.initState();
    // refresco automático del QR cada 45s
    _qrTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) setState(() => _qrSalt = DateTime.now().millisecondsSinceEpoch);
    });
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi credencial'),
      ),
      body: _user == null
          ? const _NoLoginCard()
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('credenciales')
                  .doc(_user!.uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || !snap.data!.exists) {
                  return _NoCredentialCard(onSolicitar: _solicitar);
                }

                final data = snap.data!.data()!;
                final tier = (data['tier'] ?? 'CLASICA').toString().toUpperCase();
                final numero = (data['numero'] ?? '—').toString();
                final nombre = _user!.displayName ?? 'Titular';
                final expTs = (data['expira'] is Timestamp)
                    ? (data['expira'] as Timestamp).toDate()
                    : null;
                final estado = (data['estado'] ?? 'activa').toString();
                final expirada = expTs != null && expTs.isBefore(DateTime.now());

                final theme = _tierTheme(tier);

                // QR payload con anti-replay (salt + ts)
                final payload = jsonEncode({
                  'app': 'descabio',
                  'uid': _user!.uid,
                  'tier': tier,
                  'num': numero,
                  'ts': DateTime.now().millisecondsSinceEpoch,
                  'salt': _qrSalt ^ Random().nextInt(1 << 20),
                });

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  children: [
                    _CredencialCard(
                      gradient: theme.gradient,
                      title: 'CREDENCIAL ${theme.label.toUpperCase()}',
                      numero: numero,
                      titular: nombre,
                      expira: expTs,
                      estadoLabel: expirada ? 'Expirada' : (estado == 'activa' ? 'Activa' : estado),
                      estadoColor: expirada ? cs.error :
                        (estado == 'activa' ? cs.secondary : cs.outline),
                      qr: QrImageView(
                        data: payload,
                        size: 140,
                        version: QrVersions.auto,
                        backgroundColor: Colors.white,
                        gapless: false,
                      ),
                      disabled: expirada || estado != 'activa',
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _openBeneficios(theme.id),
                            icon: const Icon(Icons.loyalty_outlined),
                            label: const Text('Ver beneficios adheridos'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _refrescarQR,
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text('Actualizar QR'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: numero));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Número de credencial copiado')),
                              );
                            },
                            icon: const Icon(Icons.copy_all_outlined),
                            label: const Text('Copiar número'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),
                    const _ComoUsarla(),
                  ],
                );
              },
            ),
    );
  }

  /* ───────── acciones ───────── */

  Future<void> _solicitar() async {
    if (_user == null) return;

    final uid   = _user!.uid;
    final email = _user!.email ?? '';
    final name  = _user!.displayName ?? '';

    // 👉 Una solicitud por usuario: usamos el UID como ID del documento
    final ref = FirebaseFirestore.instance
        .collection('solicitudes_credenciales')
        .doc(uid);

    try {
      await ref.set({
        'uid': uid,
        'email': email,
        'displayName': name,
        'emailLower': email.toLowerCase(),
        'nameLower': name.toLowerCase(),
        'estado': 'pendiente',   // compat Admin
        'status': 'pendiente',   // compat Admin
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // no duplica si ya existe

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada. Te avisamos cuando esté aprobada.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la solicitud: ${e.message ?? e.code}')),
      );
    }
  }

  void _refrescarQR() {
    setState(() => _qrSalt = DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _openBeneficios(String tierId) async {
    final cs = Theme.of(context).colorScheme;

    // Comercios y mayoristas adheridos (aceptan credencial)
    final comercios = await FirebaseFirestore.instance
        .collection('comercios')
        .where('aceptaCredencial', isEqualTo: true)
        .limit(200)
        .get();

    final mayoristas = await FirebaseFirestore.instance
        .collection('mayoristas')
        .where('aceptaCredencial', isEqualTo: true)
        .limit(200)
        .get();

    List<_BenefItem> parse(QuerySnapshot<Map<String, dynamic>> qs, String tipo) {
      return qs.docs.map((d) {
        final m = d.data();
        final nombre = (m['nombre'] ?? '—').toString();
        final b = (m['beneficios'] ?? {}) as Map<String, dynamic>;
        final perc = (b[tierId] as num?)?.toDouble();
        if (perc == null) return null;
        return _BenefItem(id: d.id, tipo: tipo, nombre: nombre, porcentaje: perc);
      }).whereType<_BenefItem>().toList();
    }

    final items = [
      ...parse(comercios, 'comercio'),
      ...parse(mayoristas, 'mayorista'),
    ]..sort((a, b) => b.porcentaje.compareTo(a.porcentaje));

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.local_offer_outlined),
                title: const Text('Beneficios adheridos'),
                subtitle: Text(
                  items.isEmpty
                      ? 'No encontramos locales para tu credencial.'
                      : 'Mostrando ${items.length} locales',
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * .6,
                ),
                child: items.isEmpty
                    ? Center(
                        child: Text('Pronto habrá más beneficios',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      )
                    : ListView.separated(
                        itemBuilder: (_, i) {
                          final it = items[i];
                          return ListTile(
                            leading: Icon(
                              it.tipo == 'comercio'
                                  ? Icons.store_mall_directory
                                  : Icons.warehouse_outlined,
                            ),
                            title: Text(it.nombre,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '${it.porcentaje.toStringAsFixed(0)}% con tu credencial'),
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemCount: items.length,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ───────── helpers ───────── */

  _TierTheme _tierTheme(String t) {
    switch (t.toUpperCase()) {
      case 'PREMIUM':
        return _TierTheme(
          id: 'PREMIUM',
          label: 'Premium',
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFF6B23B)],
          ),
        );
      case 'PLUS':
        return _TierTheme(
          id: 'PLUS',
          label: 'Plus',
          gradient: const LinearGradient(
            colors: [Color(0xFF4F78FF), Color(0xFF6CC3FF)],
          ),
        );
      default:
        return _TierTheme(
          id: 'CLASICA',
          label: 'Clásica',
          gradient: const LinearGradient(
            colors: [Color(0xFFBDBDBD), Color(0xFFE0E0E0)],
          ),
        );
    }
  }
}

class _NoLoginCard extends StatelessWidget {
  const _NoLoginCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 72, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text(
              'Iniciá sesión para ver tu credencial',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCredentialCard extends StatelessWidget {
  final VoidCallback onSolicitar;
  const _NoCredentialCard({required this.onSolicitar});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined, size: 72, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('Todavía no tenés credencial',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Podés solicitarla y te la activamos cuando esté lista.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSolicitar,
              icon: const Icon(Icons.send),
              label: const Text('Solicitar credencial'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CredencialCard extends StatelessWidget {
  final LinearGradient gradient;
  final String title;
  final String numero;
  final String titular;
  final DateTime? expira;
  final String estadoLabel;
  final Color estadoColor;
  final QrImageView qr;
  final bool disabled;

  const _CredencialCard({
    required this.gradient,
    required this.title,
    required this.numero,
    required this.titular,
    required this.expira,
    required this.estadoLabel,
    required this.estadoColor,
    required this.qr,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.15),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.black87),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nº $numero',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Titular: $titular',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(expira != null
                      ? 'Válida hasta: ${_fmt(expira!)}'
                      : 'Sin vencimiento'),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.85),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      estadoLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: estadoColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: qr,
          ),
        ],
      ),
    );

    if (!disabled) return card;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.white60, BlendMode.saturation),
      child: card,
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _ComoUsarla extends StatelessWidget {
  const _ComoUsarla();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cómo usar tu credencial',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          '• Mostrá el QR en caja.\n'
          '• El comercio escanea y valida la categoría.\n'
          '• Si el local tiene beneficio activo para tu categoría, se aplica el descuento.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TierTheme {
  final String id;
  final String label;
  final LinearGradient gradient;
  _TierTheme({required this.id, required this.label, required this.gradient});
}

class _BenefItem {
  final String id;
  final String tipo; // comercio | mayorista
  final String nombre;
  final double porcentaje;
  _BenefItem({
    required this.id,
    required this.tipo,
    required this.nombre,
    required this.porcentaje,
  });
}