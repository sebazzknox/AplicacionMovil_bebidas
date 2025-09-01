import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'ofertas_page.dart';
import 'admin_state.dart'; // adminMode

class PromosDestacadas extends StatelessWidget {
  const PromosDestacadas({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final now = Timestamp.fromDate(DateTime.now());
    // ⬇️ SIN filtro 'visible' para no ocultar promos viejas
    final q = FirebaseFirestore.instance
        .collection('ofertas')
        .where('hasta', isGreaterThanOrEqualTo: now)
        .orderBy('hasta')
        .limit(12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                'Promos destacadas',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              // Botón Agregar solo si admin
              ValueListenableBuilder<bool>(
                valueListenable: adminMode,
                builder: (_, isAdmin, __) {
                  if (!isAdmin) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/admin/nueva-promo'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Agregar'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  );
                },
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OfertasPage()),
                  );
                },
                child: const Text('Ver todas'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 300,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _ShimmerList(height: 240);
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No se pudieron cargar las promos.',
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay promos activas en este momento'),
                  ),
                );
              }

              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  final titulo = (d['titulo'] ?? 'Promo') as String;
                  final descripcion = (d['descripcion'] ?? '') as String;
                  final comercioNombre =
                      (d['comercioNombre'] ?? 'Comercio') as String;

                  final precioOriginal = _asDouble(d['precioOriginal']);
                  final precioOferta = _asDouble(d['precioOferta']);
                  final hastaTs = d['hasta'] as Timestamp?;
                  final img = (d['img'] ?? '') as String?;

                  final descuentoPct = (precioOriginal != null &&
                          precioOferta != null &&
                          precioOriginal > 0)
                      ? (((precioOriginal - precioOferta) / precioOriginal) *
                              100)
                          .round()
                      : null;

                  final venceEn = _venceEnTexto(hastaTs?.toDate());

                  return _PromoCard(
                    imageUrl: img,
                    titulo: titulo,
                    comercio: comercioNombre,
                    descripcion: descripcion,
                    precioOriginal: precioOriginal,
                    precioOferta: precioOferta,
                    descuentoPct: descuentoPct,
                    venceEn: venceEn,
                    onTap: () {
  final comercioId = (d['comercioId'] ?? '') as String;
  if (comercioId.isNotEmpty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfertasPage(
          filterComercioId: comercioId,
          filterComercioName: comercioNombre, // opcional, para mostrar el nombre
        ),
      ),
    );
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OfertasPage()),
    );
  }
},
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  static String _venceEnTexto(DateTime? hasta) {
    if (hasta == null) return '';
    final now = DateTime.now();
    final diff = hasta.difference(now);
    if (diff.inSeconds <= 0) return 'Vencida';
    if (diff.inHours < 24) return 'Vence hoy';
    final d = diff.inDays;
    if (d == 1) return 'Vence mañana';
    return 'Vence en $d días';
  }
}

class _PromoCard extends StatelessWidget {
  final String? imageUrl;
  final String titulo;
  final String comercio;
  final String descripcion;
  final double? precioOriginal;
  final double? precioOferta;
  final int? descuentoPct;
  final String venceEn;
  final VoidCallback onTap;

  const _PromoCard({
    required this.imageUrl,
    required this.titulo,
    required this.comercio,
    required this.descripcion,
    required this.precioOriginal,
    required this.precioOferta,
    required this.descuentoPct,
    required this.venceEn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SizedBox(
      width: 280,
      child: Material(
        color: cs.surface,
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 8,
                  child: (imageUrl != null && imageUrl!.isNotEmpty)
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imgFallback(cs),
                          loadingBuilder: (c, w, prog) {
                            if (prog == null) return w;
                            return _imgFallback(cs);
                          },
                        )
                      : _imgFallback(cs),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (descuentoPct != null && descuentoPct! > 0)
                          _Badge(text: '-$descuentoPct%'),
                        if (venceEn.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _Badge(
                            text: venceEn,
                            bg: cs.secondaryContainer,
                            fg: cs.onSecondaryContainer,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      comercio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (descripcion.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (precioOferta != null)
                          Text(
                            _precio(precioOferta!),
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.primary,
                            ),
                          ),
                        const SizedBox(width: 8),
                        if (precioOriginal != null && precioOferta != null)
                          Text(
                            _precio(precioOriginal!),
                            style: text.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _precio(double v) {
    final s = v.round().toString();
    final withDots = s.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '\$ $withDots';
  }

  Widget _imgFallback(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.local_offer,
          color: cs.onPrimaryContainer.withOpacity(.8), size: 42),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color? bg;
  final Color? fg;
  const _Badge({required this.text, this.bg, this.fg});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (bg ?? cs.primaryContainer).withOpacity(.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg ?? cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  final double height;
  const _ShimmerList({required this.height});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) {
        return Container(
          width: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: base.withOpacity(.05),
            border: Border.all(color: base.withOpacity(.08)),
          ),
        );
      },
    );
  }
}