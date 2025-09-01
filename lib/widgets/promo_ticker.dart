// lib/widgets/promo_ticker.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PromoTicker extends StatefulWidget {
  final VoidCallback? onTap;
  const PromoTicker({super.key, this.onTap});

  @override
  State<PromoTicker> createState() => _PromoTickerState();
}

class _PromoTickerState extends State<PromoTicker> {
  int _idx = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtPrecio(dynamic v) {
    if (v is num) {
      final s = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
      return '\$ $s';
    }
    return '';
  }

  String _fmtFecha(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fin = DateTime(d.year, d.month, d.day);
    if (fin.isBefore(today)) return '· finalizada';
    if (fin == today) return '· vence hoy';
    return '· vence ${d.day.toString().padLeft(2,"0")}/${d.month.toString().padLeft(2,"0")}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final ofertasStream = FirebaseFirestore.instance
        .collectionGroup('ofertas')
        .where('activa', isEqualTo: true)
        .orderBy('fechaFin')
        .limit(10)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: ofertasStream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();

        // arranca/renueva el rotador
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 4), (_) {
          if (!mounted) return;
          setState(() => _idx = (_idx + 1) % docs.length);
        });

        final d = docs[_idx].data() as Map<String, dynamic>;
        final titulo = (d['titulo'] ?? d['nombre'] ?? 'Oferta').toString();
        final comercio =
            (d['comercioNombre'] ?? d['comercioName'] ?? '').toString();
        final precio = _fmtPrecio(d['precioNuevo']);
        final fin = _fmtFecha((d['fechaFin'] as Timestamp?)?.toDate());

        final text =
            '🔥 $titulo ${comercio.isNotEmpty ? "— $comercio" : ""} ${precio.isNotEmpty ? "· $precio" : ""} $fin';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEDE9FE), Color(0xFFF5E1F7)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .3),
                    end: Offset.zero,
                  ).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(
                  text,
                  key: ValueKey(_idx),
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(.85),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}