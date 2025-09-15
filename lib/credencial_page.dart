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
        actions: [
          IconButton(
            tooltip: 'Planes y beneficios',
            icon: const Icon(Icons.info_outline),
            onPressed: _showPlanesSheet,
          ),
        ],
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
                  // 👉 si no tiene credencial emitida, mostramos estado de solicitud (si existe)
                  return _SolicitudStatusCard(onSolicitar: _showPlanesSheet);
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

  // CTA viejo -> ahora abre el selector de planes
  Future<void> _solicitar() async => _showPlanesSheet();

  // Abre hoja con info de planes + permite elegir y solicitar uno
  Future<void> _showPlanesSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlanesYBeneficiosSheet(onElegirPlan: _solicitarTier),
    );
  }

  // Crear solicitud con la categoría elegida
  Future<void> _solicitarTier(String tierId) async {
    if (_user == null) return;
    final ref = FirebaseFirestore.instance
        .collection('solicitudes_credenciales')
        .doc(_user!.uid); // una solicitud por usuario

    final already = await ref.get();
    if (already.exists) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya enviaste una solicitud.')),
      );
      return;
    }

    try {
      await ref.set({
        'uid': _user!.uid,
        'email': _user!.email,
        'displayName': _user!.displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'estado': 'pendiente',     // alineado con reglas
        'categoria': tierId,       // CLASICA | PLUS | PREMIUM
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada. Te avisamos cuando esté lista.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la solicitud: $e')),
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

/* ================== WIDGETS AUXILIARES ================== */

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

/// Muestra el estado de la solicitud (si existe), o el CTA para solicitar.
class _SolicitudStatusCard extends StatelessWidget {
  final VoidCallback onSolicitar; // abre el selector de planes
  const _SolicitudStatusCard({required this.onSolicitar});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const _NoLoginCard();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('solicitudes_credenciales')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        // Si no hay doc de solicitud, mostramos el CTA para solicitar
        if (!snap.hasData || !snap.data!.exists) {
          return _NoCredentialCard(onSolicitar: onSolicitar);
        }

        final data = snap.data!.data()!;
        final estado = (data['estado'] ?? data['status'] ?? 'pendiente').toString();
        final createdAt = data['createdAt'];
        final fecha = (createdAt is Timestamp)
            ? '${createdAt.toDate().day.toString().padLeft(2,'0')}/${createdAt.toDate().month.toString().padLeft(2,'0')}'
            : '';
        final cat = (data['categoria'] ?? '—').toString();

        IconData icon;
        Color color;
        String title;
        String subtitle;

        switch (estado) {
          case 'aprobada':
          case 'approved':
            icon = Icons.verified_outlined;
            color = cs.secondary;
            title = 'Solicitud aprobada';
            subtitle = 'Tu credencial $cat se emitirá en breve.';
            break;
          case 'rechazada':
          case 'denied':
            icon = Icons.block_outlined;
            color = cs.error;
            title = 'Solicitud rechazada';
            subtitle = 'Podés volver a solicitar más adelante.';
            break;
          default:
            icon = Icons.hourglass_top_outlined;
            color = cs.primary;
            title = 'Solicitud enviada';
            subtitle = 'Recibida el $fecha • Plan: $cat';
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 72, color: color),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NoCredentialCard extends StatelessWidget {
  final VoidCallback onSolicitar; // ahora abre el selector de planes
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
              'Elegí tu plan y solicitá la credencial. La activamos cuando esté lista.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSolicitar,
              icon: const Icon(Icons.send),
              label: const Text('Elegir plan y solicitar'),
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

/* ================== PLANES & BENEFICIOS (hoja) ================== */

class _PlanesYBeneficiosSheet extends StatelessWidget {
  final void Function(String tierId) onElegirPlan;
  const _PlanesYBeneficiosSheet({required this.onElegirPlan});

  @override
  Widget build(BuildContext context) {
    final plans = _TierPlan.plans;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.verified_outlined),
              title: Text('Planes de credencial'),
              subtitle: Text('Elegí el plan que mejor se adapte a vos'),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemBuilder: (_, i) {
                  final p = plans[i];
                  return _PlanCard(
                    plan: p,
                    onElegir: () => onElegirPlan(p.id),
                    chipColor: cs.primaryContainer,
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: plans.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _TierPlan plan;
  final VoidCallback onElegir;
  final Color chipColor;

  const _PlanCard({
    required this.plan,
    required this.onElegir,
    required this.chipColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: plan.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CREDENCIAL ${plan.label.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: -6,
              children: plan.badges
                  .map((b) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.85),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(b,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black87)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            ...plan.features.map((f) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.check_circle_outline, size: 18, color: Colors.black87),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f,
                          style: const TextStyle(
                              color: Colors.black87, height: 1.2)),
                    ),
                  ],
                )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                ),
                onPressed: onElegir,
                icon: const Icon(Icons.send),
                label: const Text('Solicitar esta credencial'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================== MODELOS ================== */

class _TierTheme {
  final String id;
  final String label;
  final LinearGradient gradient;
  _TierTheme({required this.id, required this.label, required this.gradient});
}

class _TierPlan {
  final String id;
  final String label;
  final LinearGradient gradient;
  final List<String> badges;   // chips cortos
  final List<String> features; // bullets

  const _TierPlan({
    required this.id,
    required this.label,
    required this.gradient,
    required this.badges,
    required this.features,
  });

  static const plans = <_TierPlan>[
    _TierPlan(
      id: 'CLASICA',
      label: 'Clásica',
      gradient: LinearGradient(colors: [Color(0xFFBDBDBD), Color(0xFFE0E0E0)]),
      badges: ['Hasta 10%', 'QR digital'],
      features: [
        'Descuentos de 5–10% en bebidas en locales adheridos.',
        'Promos básicas en packs (6, 12 unidades) según disponibilidad.',
        'QR digital y número de credencial para validar en caja.',
      ],
    ),
    _TierPlan(
      id: 'PLUS',
      label: 'Plus',
      gradient: LinearGradient(colors: [Color(0xFF4F78FF), Color(0xFF6CC3FF)]),
      badges: ['Hasta 20%', 'Prioridad'],
      features: [
        'Descuentos de 10–20% en bebidas en locales adheridos.',
        'Acceso anticipado a promos de bebidas, combos y nuevas etiquetas.',
        'Sorteos y bonus en packs/cajas seleccionadas.',
      ],
    ),
    _TierPlan(
      id: 'PREMIUM',
      label: 'Premium',
      gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFF6B23B)]),
      badges: ['Hasta 30%', 'Combos exclusivos', 'Top tier'],
      features: [
        'Descuentos de 20–30% en bebidas en locales adheridos.',
        'Bonificaciones especiales en packs y combos de bebidas, incluso mayoristas.',
        'Precios preferenciales por volumen y beneficios exclusivos en etiquetas premium.',
      ],
    ),
  ];
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