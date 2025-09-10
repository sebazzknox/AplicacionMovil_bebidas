// lib/ofertas_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show FontFeature;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'comercio_detalle_page.dart';
import 'admin_state.dart';

/* ───────────── Utils ───────────── */

String _fmtFecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String optimizeCloudinary(
  String url, {
  String tr = 'f_auto,q_auto,c_fill,ar_1:1,w_84,h_84',
}) {
  if (url.isEmpty) return url;
  const marker = '/image/upload/';
  final i = url.indexOf(marker);
  if (i == -1) return url;
  return url.replaceFirst(marker, '$marker$tr/');
}

double? _distanceMeters({
  required double? la1,
  required double? ln1,
  required double? la2,
  required double? ln2,
}) {
  if ([la1, ln1, la2, ln2].any((e) => e == null)) return null;
  const R = 6371000.0;
  final dLat = (la2! - la1!) * (pi / 180);
  final dLon = (ln2! - ln1!) * (pi / 180);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(la1 * (pi / 180)) *
          cos(la2 * (pi / 180)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

String? _uid() => FirebaseAuth.instance.currentUser?.uid;

/* ───────────── Página ───────────── */

class OfertasPage extends StatefulWidget {
  final String? filterComercioId;
  final String? filterComercioName;

  const OfertasPage({
    super.key,
    this.filterComercioId,
    this.filterComercioName,
  });

  @override
  State<OfertasPage> createState() => _OfertasPageState();
}

enum _Orden { recientes, fin, mayorOff, cercania }

class _OfertasPageState extends State<OfertasPage> {
  final _picker = ImagePicker();
  XFile? _fotoTmp;

  String? _filtroComercioId;
  String? _filtroComercioNombre;
  bool _soloActivas = false;
  bool _soloFavoritas = false;
  _Orden _orden = _Orden.recientes;

  Position? _pos;

  // admin live
  bool _isAdminDoc = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  @override
  void initState() {
    super.initState();
    _filtroComercioId = widget.filterComercioId;
    _filtroComercioNombre = widget.filterComercioName;
    _watchAdmin();
  }

  void _watchAdmin() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      _userSub?.cancel();
      if (u == null) {
        if (mounted) setState(() => _isAdminDoc = false);
        return;
      }
      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .snapshots()
          .listen((doc) {
        final m = doc.data() ?? {};
        // Respetar SOLO el booleano isAdmin en Firestore
        final byBool = (m['isAdmin'] ?? false) == true;
        if (mounted) setState(() => _isAdminDoc = byBool);
      });
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _ensureLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      if (perm == LocationPermission.deniedForever) return;
      _pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final baseCol = FirebaseFirestore.instance.collection('ofertas');
    final uid = _uid();

    // ✅ Admin UI solo si el doc de Firestore dice isAdmin: true
    final isAdminUI = _isAdminDoc;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ofertas'),
        actions: [
          if ((_filtroComercioId?.isNotEmpty ?? false) ||
              _soloActivas ||
              _soloFavoritas ||
              _orden != _Orden.recientes)
            IconButton(
              tooltip: 'Limpiar filtros',
              onPressed: () => setState(() {
                _filtroComercioId = null;
                _filtroComercioNombre = null;
                _soloActivas = false;
                _soloFavoritas = false;
                _orden = _Orden.recientes;
              }),
              icon: const Icon(Icons.filter_alt_off),
            ),
          const SizedBox(width: 4),
        ],
      ),

      body: Column(
        children: [
          const _DynamicBanner(),
          const _OfertasCarrusel(),

          _FiltrosBar(
            filtroComercioNombre: (_filtroComercioNombre?.isNotEmpty ?? false)
                ? _filtroComercioNombre
                : (_filtroComercioId?.isNotEmpty ?? false)
                    ? 'ID: $_filtroComercioId'
                    : null,
            soloActivas: _soloActivas,
            soloFavoritas: _soloFavoritas && uid != null,
            orden: _orden,
            onElegirComercio: () async {
              final picked = await _seleccionarComercio(context);
              if (picked != null) {
                setState(() {
                  _filtroComercioId = picked['id'];
                  _filtroComercioNombre = picked['nombre'];
                });
              }
            },
            onToggleActivas: (v) => setState(() => _soloActivas = v),
            onToggleFavoritas:
                uid == null ? null : (v) => setState(() => _soloFavoritas = v),
            onOrdenChanged: (o) async {
              setState(() => _orden = o);
              if (o == _Orden.cercania && _pos == null) {
                await _ensureLocation();
              }
            },
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: baseCol.orderBy('fin', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _SkeletonList();
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final offersDocs = (snap.data?.docs ?? []).toList();

                if (uid != null) {
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .snapshots(),
                    builder: (context, userSnap) {
                      final u = userSnap.data?.data() ?? {};
                      final favMap =
                          (u['favoritos'] as Map<String, dynamic>?) ?? {};
                      final favIds = favMap.entries
                          .where((e) => e.value == true)
                          .map((e) => e.key)
                          .toSet();
                      return _buildList(offersDocs, favIds, isAdminUI);
                    },
                  );
                }
                return _buildList(offersDocs, const <String>{}, isAdminUI);
              },
            ),
          ),
        ],
      ),

      floatingActionButton: isAdminUI
          ? FloatingActionButton.extended(
              onPressed: () => _abrirFormOferta(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva oferta'),
            )
          : null,
    );
  }

  /* ───────────── Lista ───────────── */

  Widget _buildList(
    List<DocumentSnapshot<Map<String, dynamic>>> docsAll,
    Set<String> favIds,
    bool isAdminUI,
  ) {
    final filtered = docsAll.where((d) {
      final data = d.data() ?? {};
      final activa = (data['activa'] ?? true) == true;

      final inicio = (data['inicio'] as Timestamp?)?.toDate();
      final fin = (data['fin'] as Timestamp?)?.toDate();
      final now = DateTime.now();
      final programada = inicio != null && inicio.isAfter(now);
      final finalizada = fin != null && fin.isBefore(now);

      if (_soloActivas && (!activa || programada || finalizada)) return false;

      final comercioId = data['comercioId'] as String?;
      if ((_filtroComercioId?.isNotEmpty ?? false) &&
          comercioId != _filtroComercioId) {
        return false;
      }

      if (_soloFavoritas && !favIds.contains(d.id)) return false;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return _EmptyState(
        title: 'Sin ofertas',
        subtitle: 'No encontramos ofertas para los filtros elegidos.',
        ctaLabel: isAdminUI ? 'Crear oferta' : null,
        onCta: isAdminUI ? () => _abrirFormOferta() : null,
      );
    }

    int byActive(d) => (d.data()?['activa'] == true) ? 1 : 0;
    double offPct(Map<String, dynamic> m) {
      final po = (m['precioOriginal'] ?? m['precio']) as num?;
      final pf = (m['precioOferta'] ?? m['promoPrecio']) as num?;
      if (po == null || pf == null || po <= 0) return 0;
      return (1 - (pf / po)) * 100;
    }

    Map<String, double?> dist = {};
    if (_orden == _Orden.cercania && _pos != null) {
      for (final d in filtered) {
        final m = d.data()!;
        final la = (m['lat'] as num?)?.toDouble();
        final ln = (m['lng'] as num?)?.toDouble();
        dist[d.id] = _distanceMeters(
          la1: _pos!.latitude,
          ln1: _pos!.longitude,
          la2: la,
          ln2: ln,
        );
      }
    }

    filtered.sort((a, b) {
      switch (_orden) {
        case _Orden.recientes:
          final byA = byActive(b) - byActive(a);
          if (byA != 0) return byA;
          final ad = (a.data()?['updatedAt'] ??
                  a.data()?['createdAt'] ??
                  a.data()?['fin']) as Timestamp?;
          final bd = (b.data()?['updatedAt'] ??
                  b.data()?['createdAt'] ??
                  b.data()?['fin']) as Timestamp?;
          return (bd?.toDate() ?? DateTime(0))
              .compareTo(ad?.toDate() ?? DateTime(0));
        case _Orden.fin:
          final ad = (a.data()?['fin'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bd = (b.data()?['fin'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return ad.compareTo(bd);
        case _Orden.mayorOff:
          final ao = offPct(a.data()!);
          final bo = offPct(b.data()!);
          return bo.compareTo(ao);
        case _Orden.cercania:
          final da = dist[a.id] ?? double.infinity;
          final db = dist[b.id] ?? double.infinity;
          return da.compareTo(db);
      }
    });

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final d = filtered[i];
        final data = d.data()!;
        final titulo = (data['titulo'] ?? '') as String;
        final desc = (data['descripcion'] ?? '') as String;
        final foto = (data['fotoUrl'] ?? data['img']) as String?;
        final activa = (data['activa'] ?? true) as bool;
        final comercioId = data['comercioId'] as String?;
        final inicio = (data['inicio'] as Timestamp?)?.toDate();
        final fin = (data['fin'] as Timestamp?)?.toDate();

        final double? precioOriginal =
            (data['precioOriginal'] as num?)?.toDouble() ??
                (data['precio'] as num?)?.toDouble();
        final double? precioOferta =
            (data['precioOferta'] as num?)?.toDouble() ??
                (data['promoPrecio'] as num?)?.toDouble();
        final double? descuento = (precioOriginal != null &&
                precioOferta != null &&
                precioOriginal > 0)
            ? (1 - (precioOferta / precioOriginal)) * 100
            : null;

        final now = DateTime.now();
        final programada = inicio != null && inicio.isAfter(now);
        final finalizada = fin != null && fin.isBefore(now);

        final created =
            (data['createdAt'] as Timestamp?)?.toDate() ?? now;
        final isNuevo = now.difference(created).inHours <= 72;
        final favCount = (data['favoritesCount'] as num?)?.toInt() ?? 0;
        final isPopular = favCount >= 10;

        final la = (data['lat'] as num?)?.toDouble();
        final ln = (data['lng'] as num?)?.toDouble();
        final distM = _pos == null
            ? null
            : _distanceMeters(
                la1: _pos!.latitude,
                ln1: _pos!.longitude,
                la2: la,
                ln2: ln,
              );

        final stock = (data['stock'] as num?)?.toInt();
        final reservado = (data['stockReservado'] as num?)?.toInt() ?? 0;
        final quedan = (stock != null) ? (stock - reservado).clamp(0, 1 << 31) : null;

        final uid = _uid();
        final isFav = uid != null && favIds.contains(d.id);
        final isDraft = (data['draft'] ?? false) == true;

        return Opacity(
          opacity: isDraft ? .7 : 1,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            elevation: 1.0,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (comercioId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Esta oferta no tiene un comercio vinculado.'),
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ComercioDetallePage(comercioId: comercioId),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 84,
                        height: 84,
                        child: (foto == null || foto.isEmpty)
                            ? Container(
                                color: Colors.black12,
                                child: const Icon(Icons.local_offer, size: 32),
                              )
                            : Image.network(
                                optimizeCloudinary(foto),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ⬇️ lista directa de widgets
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  titulo,
                                  style: Theme.of(context).textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    isFav ? 'Quitar de favoritos' : 'Guardar',
                                icon: Icon(
                                  isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFav
                                      ? Colors.pink
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                                onPressed: () async {
                                  final ok =
                                      await _toggleFavorito(d.id, isFav);
                                  if (!ok && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'No pudimos actualizar favorito'),
                                      ),
                                    );
                                  }
                                },
                              ),
                              _BellSubDoc(ofertaId: d.id),
                              if (isAdminUI)
                                PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'edit') {
                                      _abrirFormOferta(doc: d);
                                    } else if (v == 'delete') {
                                      final ok = await _confirmarBorrado(
                                          context, titulo);
                                      if (ok) {
                                        await _deleteFotoByPath(
                                            data['fotoPath'] as String?);
                                        await d.reference.delete();
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'edit', child: Text('Editar')),
                                    PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Eliminar')),
                                  ],
                                ),
                            ],
                          ),

                          Wrap(
                            spacing: 6,
                            runSpacing: -6,
                            children: [
                              if (isNuevo) _chipMini('🆕 Nuevo'),
                              if (isPopular) _chipMini('🔥 Popular'),
                              if (programada) _chipMini('⏳ Programada'),
                              if (finalizada) _chipMini('⛔ Finalizada'),
                              if (isDraft) _chipMini('📝 Borrador'),
                              if (quedan != null)
                                _chipMini(quedan > 0 ? 'Quedan $quedan' : 'Agotada'),
                              if (distM != null)
                                _chipMini(
                                  distM >= 1000
                                      ? '${(distM / 1000).toStringAsFixed(1)} km'
                                      : '${distM.round()} m',
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          if (desc.isNotEmpty)
                            Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),

                          if (precioOferta != null || precioOriginal != null)
                            Row(
                              children: [
                                if (precioOferta != null)
                                  Text(
                                    '\$ ${precioOferta.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800),
                                  ),
                                if (precioOriginal != null &&
                                    precioOferta != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '\$ ${precioOriginal.toStringAsFixed(0)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline,
                                        ),
                                  ),
                                ],
                                if (descuento != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '-${descuento.round()}%',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                          const SizedBox(height: 6),

                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (!finalizada && activa && !programada)
                                      ? Colors.green.withOpacity(.15)
                                      : Colors.grey.withOpacity(.2),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  (!finalizada && activa && !programada)
                                      ? 'Activa'
                                      : programada
                                          ? 'Programada'
                                          : 'Finalizada',
                                  style:
                                      Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  [
                                    if (inicio != null)
                                      'Desde ${_fmtFecha(inicio)}',
                                    if (fin != null) 'Hasta ${_fmtFecha(fin)}',
                                  ].join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                icon:
                                    const Icon(Icons.confirmation_number),
                                label: const Text('Cupón'),
                                onPressed: () =>
                                    _obtenerCupon(context, d.id, titulo),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.ios_share),
                                label: const Text('Compartir'),
                                onPressed: () async {
                                  final texto =
                                      '$titulo\n${desc.isNotEmpty ? '$desc\n' : ''}Oferta en Descabio: https://descabio.app/oferta/${d.id}';
                                  await Clipboard.setData(
                                      ClipboardData(text: texto));
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Texto copiado al portapapeles')),
                                    );
                                  }
                                },
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.chat),
                                label: const Text('WhatsApp'),
                                onPressed: () => _contactarWhatsApp(
                                  context,
                                  comercioId: comercioId,
                                  titulo: titulo,
                                ),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.call),
                                label: const Text('Llamar'),
                                onPressed: () => _llamarComercio(
                                    context,
                                    comercioId: comercioId),
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
          ),
        );
      },
    );
  }

  /* ───────────── Acciones (favorito / cupón) ───────────── */

  Future<bool> _toggleFavorito(String ofertaId, bool isFav) async {
    final uid = _uid();
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iniciá sesión para guardar favoritos.')),
      );
      return false;
    }
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(uid);
      if (isFav) {
        await userRef.update({'favoritos.$ofertaId': FieldValue.delete()});
      } else {
        await userRef.set({
          'favoritos': {ofertaId: true}
        }, SetOptions(merge: true));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _obtenerCupon(
      BuildContext context, String ofertaId, String titulo) async {
    final uid = _uid();
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iniciá sesión para obtener cupones.')),
      );
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    String code;
    try {
      final snap = await userRef.get();
      final data = snap.data() ?? {};
      final Map<String, dynamic> cupones =
          (data['cupones'] as Map<String, dynamic>?) ?? {};
      final existing = cupones[ofertaId] as Map<String, dynamic>?;

      if (existing != null &&
          (existing['code'] ?? '').toString().isNotEmpty) {
        code = existing['code'].toString();
      } else {
        code = _genCode();
        await userRef.set({
          'cupones': {
            ofertaId: {
              'code': code,
              'estado': 'activo',
              'createdAt': FieldValue.serverTimestamp(),
            }
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el cupón: $e')),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tu cupón'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withOpacity(.4),
                ),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  letterSpacing: 1.2,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Mostralo en caja para canjear.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(context);
            },
            child: const Text('Copiar código'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          )
        ],
      ),
    );
  }

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /* ───────────── CRUD oferta (solo admin UI) ───────────── */

  Future<void> _abrirFormOferta(
      {DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final isEdit = doc != null;
    final data = doc?.data();

    final tituloCtrl =
        TextEditingController(text: data?['titulo'] ?? '');
    final descCtrl =
        TextEditingController(text: data?['descripcion'] ?? '');
    final precioOCtrl = TextEditingController(
        text: (data?['precioOriginal'] ?? data?['precio'])?.toString() ?? '');
    final precioFCtrl = TextEditingController(
        text: (data?['precioOferta'] ?? data?['promoPrecio'])?.toString() ?? '');
    final stockCtrl =
        TextEditingController(text: (data?['stock'] ?? '').toString());

    String? selectedComercioId = data?['comercioId'] as String? ??
        _filtroComercioId ??
        widget.filterComercioId;
    String? selectedComercioName;

    if ((selectedComercioId?.isNotEmpty ?? false)) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('comercios')
            .doc(selectedComercioId)
            .get();
        selectedComercioName =
            (snap.data()?['nombre'] ?? '') as String?;
      } catch (_) {}
    }

    DateTime? inicio = (data?['inicio'] as Timestamp?)?.toDate();
    DateTime? fin = (data?['fin'] as Timestamp?)?.toDate();
    bool activa = (data?['activa'] ?? true) as bool;
    bool destacada = (data?['destacada'] ?? false) as bool;
    bool draft = (data?['draft'] ?? false) as bool;
    String? fotoUrlPreview = data?['fotoUrl'] as String?;
    _fotoTmp = null;

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
              title: Text(isEdit ? 'Editar oferta' : 'Nueva oferta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final x = await _picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 75,
                        );
                        if (x != null) setLocal(() => _fotoTmp = x);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: _fotoTmp != null
                              ? Image.file(File(_fotoTmp!.path),
                                  fit: BoxFit.cover)
                              : (fotoUrlPreview != null &&
                                      fotoUrlPreview!.isNotEmpty)
                                  ? Image.network(fotoUrlPreview!,
                                      fit: BoxFit.cover)
                                  : Container(
                                      color: Colors.black12,
                                      child: const Icon(Icons.add_a_photo,
                                          size: 36),
                                    ),
                        ),
                      ),
                    ),
                    if (_fotoTmp != null ||
                        (fotoUrlPreview ?? '').isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setLocal(() {
                          _fotoTmp = null;
                          fotoUrlPreview = null;
                        }),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Quitar foto'),
                      ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: tituloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: precioOCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Precio original',
                              prefixIcon: Icon(Icons.money_off),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: precioFCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Precio oferta',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: stockCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              signed: false),
                      decoration: const InputDecoration(
                        labelText: 'Stock (opcional)',
                        prefixIcon:
                            Icon(Icons.inventory_2_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),

                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked =
                            await _seleccionarComercio(context);
                        if (picked != null) {
                          setLocal(() {
                            selectedComercioId = picked['id'];
                            selectedComercioName = picked['nombre'];
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Comercio',
                          prefixIcon:
                              Icon(Icons.store_mall_directory),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          (selectedComercioName?.isNotEmpty ?? false)
                              ? selectedComercioName!
                              : (selectedComercioId?.isNotEmpty ?? false)
                                  ? 'ID: $selectedComercioId'
                                  : 'Tocá para elegir un comercio',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: Text(inicio == null
                                ? 'Desde'
                                : _fmtFecha(inicio!)),
                            onPressed: () async {
                              final today = DateTime.now();
                              final picked = await showDatePicker(
                                context: ctx,
                                firstDate:
                                    DateTime(today.year - 1),
                                lastDate:
                                    DateTime(today.year + 3),
                                initialDate: inicio ?? today,
                              );
                              if (picked != null) {
                                setLocal(() => inicio = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.event),
                            label: Text(
                                fin == null ? 'Hasta' : _fmtFecha(fin!)),
                            onPressed: () async {
                              final today = DateTime.now();
                              final picked = await showDatePicker(
                                context: ctx,
                                firstDate:
                                    DateTime(today.year - 1),
                                lastDate:
                                    DateTime(today.year + 3),
                                initialDate:
                                    fin ?? (inicio ?? today),
                              );
                              if (picked != null) {
                                setLocal(() => fin = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Text('Activa'),
                        const Spacer(),
                        Switch(
                          value: activa,
                          onChanged: (v) =>
                              setLocal(() => activa = v),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Destacada (carrusel)'),
                        const Spacer(),
                        Switch(
                          value: destacada,
                          onChanged: (v) =>
                              setLocal(() => destacada = v),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Borrador (no pública)'),
                        const Spacer(),
                        Switch(
                          value: draft,
                          onChanged: (v) =>
                              setLocal(() => draft = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Guardar')),
              ],
            ),
          ),
        ) ??
        false;

    if (!ok) {
      setState(() => _fotoTmp = null);
      return;
    }

    final titulo = tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falta el título')));
      return;
    }

    double? num(TextEditingController c) =>
        double.tryParse(c.text.replaceAll(',', '.'));

    final payload = <String, dynamic>{
      'titulo': titulo,
      'descripcion': descCtrl.text.trim(),
      'comercioId': (selectedComercioId?.isNotEmpty ?? false)
          ? selectedComercioId
          : null,
      'inicio': inicio != null
          ? Timestamp.fromDate(inicio!)
          : FieldValue.delete(),
      'fin':
          fin != null ? Timestamp.fromDate(fin!) : FieldValue.delete(),
      'precioOriginal': num(precioOCtrl),
      'precioOferta': num(precioFCtrl),
      'stock': int.tryParse(stockCtrl.text),
      'activa': activa,
      'destacada': destacada,
      'draft': draft,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final col = FirebaseFirestore.instance.collection('ofertas');

    try {
      if (isEdit) {
        await doc!.reference.update(payload);

        if (_fotoTmp != null) {
          await _deleteFotoByPath(data?['fotoPath'] as String?);
          final up = await _uploadFoto(doc.id);
          if (up != null) {
            await doc.reference
                .update({'fotoUrl': up.url, 'fotoPath': up.path});
          }
        } else if ((fotoUrlPreview ?? '').isEmpty &&
            (data?['fotoPath'] != null)) {
          await _deleteFotoByPath(data?['fotoPath'] as String?);
          await doc.reference.update({
            'fotoUrl': FieldValue.delete(),
            'fotoPath': FieldValue.delete(),
          });
        }
      } else {
        final newRef = await col.add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
          'favoritesCount': 0,
        });
        if (_fotoTmp != null) {
          final up = await _uploadFoto(newRef.id);
          if (up != null) {
            await newRef.update({'fotoUrl': up.url, 'fotoPath': up.path});
          }
        }
      }
    } finally {
      setState(() => _fotoTmp = null);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEdit ? 'Oferta actualizada' : 'Oferta creada')));
    }
  }

  Future<({String url, String path})?> _uploadFoto(String ofertaId) async {
    if (_fotoTmp == null) return null;
    final path = 'ofertas/$ofertaId/foto.jpg';
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(
        File(_fotoTmp!.path), SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    return (url: url, path: path);
  }

  Future<void> _deleteFotoByPath(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref().child(path).delete();
    } catch (_) {}
  }

  Future<bool> _confirmarBorrado(
      BuildContext context, String titulo) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirmar borrado'),
            content: Text('¿Eliminar la oferta "$titulo"?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Eliminar')),
            ],
          ),
        ) ??
        false;
  }

  Future<Map<String, String>?> _seleccionarComercio(
      BuildContext parentCtx) async {
    return await showModalBottomSheet<Map<String, String>>(
      context: parentCtx,
      isScrollControlled: true,
      builder: (ctx) {
        final col = FirebaseFirestore.instance.collection('comercios');
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.store_mall_directory),
                  title: Text('Elegir comercio'),
                ),
                Expanded(
                  child:
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: col.orderBy('nombre').snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(
                            child: Text('No hay comercios.'));
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final d = docs[i];
                          final data = d.data();
                          final nombre =
                              (data['nombre'] ?? '') as String;
                          final ciudad =
                              (data['ciudad'] ?? '') as String?;
                          final provincia =
                              (data['provincia'] ?? '') as String?;
                          final subt = [
                            if (ciudad != null && ciudad.isNotEmpty)
                              ciudad,
                            if (provincia != null &&
                                provincia.isNotEmpty)
                              provincia,
                          ].join(' • ');
                          return ListTile(
                            leading: const Icon(Icons.storefront),
                            title: Text(nombre),
                            subtitle:
                                subt.isEmpty ? null : Text(subt),
                            onTap: () => Navigator.pop(ctx, {
                              'id': d.id,
                              'nombre': nombre,
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* ───────────── Auxiliares UI ───────────── */

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    final base =
        Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.35);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
            color: base, borderRadius: BorderRadius.circular(16)),
        height: 108,
      ),
    );
  }
}

Widget _chipMini(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );

// 🔔 Suscripción a avisos de una oferta (persistencia en users/{uid}.subsOfertas)
class _BellSubDoc extends StatelessWidget {
  final String ofertaId;
  const _BellSubDoc({required this.ofertaId});

  @override
  Widget build(BuildContext context) {
    final uid = _uid();
    if (uid == null) return const SizedBox.shrink();
    final ref =
        FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final m = snap.data?.data() ?? {};
        final subs = (m['subsOfertas'] as Map<String, dynamic>?) ?? {};
        final on = subs[ofertaId] == true;

        return IconButton(
          tooltip: on ? 'Quitar avisos' : 'Avisarme',
          icon: Icon(on
              ? Icons.notifications_active
              : Icons.notifications_none),
          onPressed: () async {
            try {
              if (on) {
                await ref.update(
                    {'subsOfertas.$ofertaId': FieldValue.delete()});
              } else {
                await ref.set({
                  'subsOfertas': {ofertaId: true}
                }, SetOptions(merge: true));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No se pudo actualizar: $e')),
                );
              }
            }
          },
        );
      },
    );
  }
}

/* ───────────── Banners ───────────── */

class _DynamicBanner extends StatelessWidget {
  const _DynamicBanner();

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('banners');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: col.doc('home').snapshots(),
      builder: (context, homeSnap) {
        if (homeSnap.hasData && (homeSnap.data?.exists ?? false)) {
          final data = homeSnap.data!.data()!;
          final activo = (data['activo'] ?? true) == true;
          if (!activo) return const SizedBox(height: 0);
          return _BannerCard(
            titulo: (data['titulo'] ?? '').toString(),
            texto: (data['texto'] ?? '').toString(),
            ctaLabel: (data['ctaLabel'] ?? '').toString(),
            ctaUrl: (data['ctaUrl'] ?? '').toString(),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              col.where('activo', isEqualTo: true).limit(1).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }
            final data = snap.data!.docs.first.data();
            return _BannerCard(
              titulo: (data['titulo'] ?? '').toString(),
              texto: (data['texto'] ?? '').toString(),
              ctaLabel: (data['ctaLabel'] ?? '').toString(),
              ctaUrl: (data['ctaUrl'] ?? '').toString(),
            );
          },
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  final String titulo;
  final String texto;
  final String ctaLabel;
  final String ctaUrl;

  const _BannerCard({
    required this.titulo,
    required this.texto,
    required this.ctaLabel,
    required this.ctaUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (titulo.isEmpty && texto.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primaryContainer, cs.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (titulo.isNotEmpty)
                        Text(
                          titulo,
                          style:
                              Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (texto.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          texto,
                          style:
                              Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (ctaUrl.isNotEmpty && ctaLabel.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  FittedBox(
                    child: FilledButton.tonal(
                      onPressed: () async {
                        final uri = Uri.tryParse(ctaUrl);
                        if (uri != null) {
                          await launchUrl(uri,
                              mode:
                                  LaunchMode.externalApplication);
                        }
                      },
                      child: Text(ctaLabel),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────── Carrusel local ───────────── */

class _OfertasCarrusel extends StatefulWidget {
  const _OfertasCarrusel();

  @override
  State<_OfertasCarrusel> createState() => _OfertasCarruselState();
}

class _OfertasCarruselState extends State<_OfertasCarrusel> {
  final _pageCtrl = PageController(viewportFraction: .9);
  Timer? _timer;
  int _idx = 0;

  final List<String> _localImages = const [
    'assets/banners/imagen2x1.jpg',
    'assets/banners/prueba.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startAuto() {
    _timer?.cancel();
    if (_localImages.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _idx = (_idx + 1) % _localImages.length;
      _pageCtrl.animateToPage(
        _idx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_localImages.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: SizedBox(
        height: 148,
        child: PageView.builder(
          controller: _pageCtrl,
          itemCount: _localImages.length,
          itemBuilder: (_, i) {
            final img = _localImages[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(img, fit: BoxFit.cover),
              ),
            );
          },
        ),
      ),
    );
  }
}

/* ───────────── Filtros ───────────── */

class _FiltrosBar extends StatelessWidget {
  final String? filtroComercioNombre;
  final bool soloActivas;
  final bool soloFavoritas;
  final _Orden orden;

  final VoidCallback onElegirComercio;
  final ValueChanged<bool> onToggleActivas;
  final ValueChanged<bool>? onToggleFavoritas;
  final ValueChanged<_Orden> onOrdenChanged;

  const _FiltrosBar({
    required this.filtroComercioNombre,
    required this.soloActivas,
    required this.soloFavoritas,
    required this.orden,
    required this.onElegirComercio,
    required this.onToggleActivas,
    required this.onToggleFavoritas,
    required this.onOrdenChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.store_mall_directory),
                  label: Text(
                    (filtroComercioNombre?.isNotEmpty ?? false)
                        ? filtroComercioNombre!
                        : 'Todos los comercios',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: onElegirComercio,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => onToggleActivas(!soloActivas),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('Solo activas'),
                      const SizedBox(width: 6),
                      Switch(
                        value: soloActivas,
                        onChanged: onToggleActivas,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              if (onToggleFavoritas != null)
                FilterChip(
                  label: const Text('Solo favoritas'),
                  selected: soloFavoritas,
                  onSelected: onToggleFavoritas,
                ),
              const Text('Ordenar por:'),
              SizedBox(
                width: 220,
                child: DropdownButton<_Orden>(
                  isExpanded: true,
                  value: orden,
                  onChanged: (v) {
                    if (v != null) onOrdenChanged(v);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: _Orden.recientes,
                      child: Text('Más recientes'),
                    ),
                    DropdownMenuItem(
                      value: _Orden.fin,
                      child: Text('Próximas a vencer'),
                    ),
                    DropdownMenuItem(
                      value: _Orden.mayorOff,
                      child: Text('Mayor % OFF'),
                    ),
                    DropdownMenuItem(
                      value: _Orden.cercania,
                      child: Text('Más cerca de mí'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ───────────── Empty ───────────── */

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined,
                size: 64, color: cs.outline),
            const SizedBox(height: 12),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.outline),
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCta,
                icon: const Icon(Icons.add),
                label: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ───────────── Contacto (WhatsApp / llamar) ───────────── */

Future<void> _contactarWhatsApp(BuildContext context,
    {required String? comercioId, required String titulo}) async {
  String? tel;
  String? nombre;
  try {
    if (comercioId != null && comercioId.isNotEmpty) {
      final snap = await FirebaseFirestore.instance
          .collection('comercios')
          .doc(comercioId)
          .get();
      final d = snap.data();
      nombre = (d?['nombre'] ?? '').toString();
      tel = (d?['whatsapp'] ?? d?['telefono'] ?? d?['tel'] ?? '').toString();
    }
  } catch (_) {}
  if (tel == null || tel.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('Este comercio no tiene WhatsApp configurado.')),
    );
    return;
  }
  final phone = tel.replaceAll(RegExp(r'[^0-9+]'), '');
  final msg = Uri.encodeComponent(
      'Hola ${nombre ?? ''}! Me interesa la oferta "$titulo" que vi en DESCABIO 🛍️');
  final uri = Uri.parse('https://wa.me/$phone?text=$msg');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _llamarComercio(BuildContext context,
    {required String? comercioId}) async {
  String? tel;
  try {
    if (comercioId != null && comercioId.isNotEmpty) {
      final snap = await FirebaseFirestore.instance
          .collection('comercios')
          .doc(comercioId)
          .get();
      final d = snap.data();
      tel = (d?['telefono'] ?? d?['tel'] ?? '').toString();
    }
  } catch (_) {}
  if (tel == null || tel.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Este comercio no tiene teléfono configurado.')),
    );
    return;
  }
  final phone = tel.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri.parse('tel:$phone');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
