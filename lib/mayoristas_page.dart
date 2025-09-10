// lib/mayoristas_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show sin, cos, atan2, sqrt, pi;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

import 'comercio_detalle_page.dart';
import 'widgets/commerce_tile.dart';

/* ==========================
   Persistencia simple de favoritos (archivo JSON local)
   ========================== */
class _FavStore {
  Set<String> _ids = {};
  File? _file;

  Set<String> get ids => _ids;

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/favs.json');
      if (await _file!.exists()) {
        final txt = await _file!.readAsString();
        final data = (jsonDecode(txt) as List?) ?? const [];
        _ids = data.map((e) => e.toString()).toSet();
      } else {
        _ids = {};
      }
    } catch (_) {
      _ids = {};
    }
  }

  Future<void> _persist() async {
    try {
      if (_file == null) return;
      await _file!.writeAsString(jsonEncode(_ids.toList()));
    } catch (_) {/* no-op */}
  }

  Future<void> toggle(String id) async {
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
    await _persist();
  }
}

class MayoristasPage extends StatefulWidget {
  const MayoristasPage({super.key});

  @override
  State<MayoristasPage> createState() => _MayoristasPageState();
}

class _MayoristasPageState extends State<MayoristasPage> {
  // ---------- Filtros/UI ----------
  final _searchCtrl = TextEditingController();
  String _q = '';
  bool _fAbierto = false;
  bool _fCerca = false;
  bool _fPromos = false;
  bool _ordenDist = false; // ordenar por distancia

  // ---------- Ubicación ----------
  bool _locBusy = false;
  double? _lat;
  double? _lng;

  // Radio de “Cerca”
  double _radioKm = 10;

  // ---------- Promos ----------
  StreamSubscription<QuerySnapshot>? _promoSub;
  final Set<String> _comerciosConPromo = <String>{};

  // ---------- Favoritos ----------
  final _favStore = _FavStore();
  Set<String> _favs = {};

  @override
  void initState() {
    super.initState();
    _listenPromos();
    _initFavs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _promoSub?.cancel();
    super.dispose();
  }

  Future<void> _initFavs() async {
    await _favStore.init();
    _favs = _favStore.ids;
    if (mounted) setState(() {});
  }

  Future<void> _toggleFav(String id) async {
    await _favStore.toggle(id);
    _favs = _favStore.ids;
    if (mounted) setState(() {});
  }

  /* ================== PROMOS ================== */
  void _listenPromos() {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    _promoSub = FirebaseFirestore.instance
        .collection('ofertas')
        .where('activa', isEqualTo: true)
        .where('hasta', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
        .snapshots()
        .listen((snap) {
      final s = <String>{};
      for (final d in snap.docs) {
        final m = d.data();
        final id = (m['comercioId'] ?? '').toString();
        if (id.isNotEmpty) s.add(id);
      }
      if (mounted) {
        setState(() {
          _comerciosConPromo
            ..clear()
            ..addAll(s);
        });
      }
    });
  }

  /* ================== UBICACIÓN ================== */
  Future<void> _ensureLocation() async {
    if (_lat != null && _lng != null) return;
    setState(() => _locBusy = true);
    try {
      final pos = await _getCurrentPosition();
      if (pos != null) {
        _lat = pos.latitude;
        _lng = pos.longitude;
      }
    } finally {
      if (mounted) setState(() => _locBusy = false);
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  // Haversine km
  double _distKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(1 - a), sqrt(a));
    return R * c;
  }

  double _deg2rad(double d) => d * (pi / 180.0);

  /* ================== ABIERTO AHORA ================== */
  String _diaHoyShort() {
    const map = {
      DateTime.monday: 'lun',
      DateTime.tuesday: 'mar',
      DateTime.wednesday: 'mie',
      DateTime.thursday: 'jue',
      DateTime.friday: 'vie',
      DateTime.saturday: 'sab',
      DateTime.sunday: 'dom',
    };
    return map[DateTime.now().weekday]!;
  }

  bool isOpenNow(Map<String, dynamic>? horarios) {
    if (horarios == null || horarios.isEmpty) return false;
    final today = _diaHoyShort();

    List<Map<String, dynamic>> rangos;
    if (horarios['rangos'] is List) {
      rangos = (horarios['rangos'] as List)
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
      if (rangos.isEmpty) return false;
    } else {
      rangos = [horarios.map((k, v) => MapEntry(k.toString(), v))];
    }

    TimeOfDay? parse(String s) {
      final p = s.split(':');
      if (p.length < 2) return null;
      return TimeOfDay(hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0);
    }

    bool dayMatches(dynamic rawDias) {
      if (rawDias == null) return true;
      if (rawDias is List) return rawDias.map((e) => e.toString()).contains(today);
      if (rawDias is String) return rawDias.toLowerCase().contains(today);
      return false;
    }

    int mm(TimeOfDay t) => t.hour * 60 + t.minute;
    final now = TimeOfDay.now();
    final nowM = mm(now);

    for (final r in rangos) {
      if (!dayMatches(r['dias'])) continue;
      final d = parse((r['desde'] ?? '').toString());
      final h = parse((r['hasta'] ?? '').toString());
      if (d == null || h == null) continue;
      final dM = mm(d), hM = mm(h);

      if (hM > dM) {
        if (nowM >= dM && nowM <= hM) return true;
      } else {
        if (nowM >= dM || nowM <= hM) return true; // cruza medianoche
      }
    }
    return false;
  }

  /* ================== Selector de radio para "Cerca" ================== */
  Future<void> _pickRadioKm() async {
    final opciones = [3.0, 5.0, 10.0, 20.0, 50.0];
    final sel = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.near_me_outlined),
              title: Text('Radio de “Cerca”'),
              subtitle: Text('Filtrar comercios por distancia'),
            ),
            for (final km in opciones)
              ListTile(
                title: Text('${km.toStringAsFixed(0)} km'),
                trailing: (_radioKm == km) ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, km),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (sel != null) setState(() => _radioKm = sel);
  }

  /* ================== UI ================== */
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Mayoristas', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 12, offset: const Offset(0, 6)),
              ]),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar por provincia, ciudad o comercio',
                  hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(.9)),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: cs.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: cs.outlineVariant.withOpacity(.35)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: cs.outlineVariant.withOpacity(.35)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: cs.primary, width: 1.2),
                  ),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
          ),

          // Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _ChipToggle(
                  icon: Icons.access_time,
                  label: 'Abierto ahora',
                  selected: _fAbierto,
                  onTap: () => setState(() => _fAbierto = !_fAbierto),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onLongPress: _pickRadioKm,
                  child: _ChipToggle(
                    icon: Icons.near_me_outlined,
                    label: _locBusy
                        ? 'Buscando...'
                        : 'Cerca (${_radioKm.toStringAsFixed(0)} km)',
                    selected: _fCerca,
                    onTap: () async {
                      if (!_fCerca || _lat == null || _lng == null) {
                        await _ensureLocation();
                      }
                      if (mounted) setState(() => _fCerca = !_fCerca);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _ChipToggle(
                  icon: Icons.swap_vert,
                  label: 'Orden: distancia',
                  selected: _ordenDist,
                  onTap: () async {
                    if (_lat == null || _lng == null) {
                      await _ensureLocation();
                    }
                    setState(() => _ordenDist = !_ordenDist);
                  },
                ),
                const SizedBox(width: 8),
                _ChipToggle(
                  icon: Icons.local_offer_outlined,
                  label: 'Promos',
                  selected: _fPromos,
                  onTap: () => setState(() => _fPromos = !_fPromos),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Lista
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('comercios')
                  .where('vendeMayorista', isEqualTo: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final docs = snap.data?.docs ?? [];

                final q = _q.trim().toLowerCase();
                final filtered = docs.where((d) {
                  final m = d.data();
                  final nombre = (m['nombre'] ?? '').toString().toLowerCase();
                  final ciudad = (m['ciudad'] ?? '').toString().toLowerCase();
                  final provincia = (m['provincia'] ?? '').toString().toLowerCase();

                  if (q.isNotEmpty && !(nombre.contains(q) || ciudad.contains(q) || provincia.contains(q))) {
                    return false;
                  }

                  if (_fPromos && !_comerciosConPromo.contains(d.id)) return false;

                  if (_fAbierto) {
                    final horarios = (m['horarios'] as Map<String, dynamic>?) ?? {};
                    if (!isOpenNow(horarios)) return false;
                  }

                  if (_fCerca) {
                    if (_lat == null || _lng == null) return false;
                    final lat = (m['lat'] as num?)?.toDouble();
                    final lng = (m['lng'] as num?)?.toDouble();
                    if (lat == null || lng == null) return false;
                    final km = _distKm(_lat!, _lng!, lat, lng);
                    if (km > _radioKm) return false;
                  }

                  return true;
                }).toList();

                // Orden
                if (_ordenDist && _lat != null && _lng != null) {
                  filtered.sort((a, b) {
                    final ma = a.data();
                    final mb = b.data();
                    final latA = (ma['lat'] as num?)?.toDouble();
                    final lngA = (ma['lng'] as num?)?.toDouble();
                    final latB = (mb['lat'] as num?)?.toDouble();
                    final lngB = (mb['lng'] as num?)?.toDouble();

                    double da = 1e9, db = 1e9;
                    if (latA != null && lngA != null) {
                      da = _distKm(_lat!, _lng!, latA, lngA);
                    }
                    if (latB != null && lngB != null) {
                      db = _distKm(_lat!, _lng!, latB, lngB);
                    }
                    return da.compareTo(db);
                  });
                } else {
                  filtered.sort((a, b) {
                    final na = (a.data()['nombre'] ?? '').toString();
                    final nb = (b.data()['nombre'] ?? '').toString();
                    return na.toLowerCase().compareTo(nb.toLowerCase());
                  });
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No hay mayoristas para mostrar.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    if (_fCerca || _ordenDist) {
                      _lat = null;
                      _lng = null;
                      await _ensureLocation();
                    }
                    setState(() {});
                    await Future.delayed(const Duration(milliseconds: 300));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) {
                      final doc = filtered[i];
                      final m = doc.data();

                      final nombre = (m['nombre'] ?? '') as String? ?? '';
                      final ciudad = (m['ciudad'] ?? '') as String? ?? '';
                      final provincia = (m['provincia'] ?? '') as String? ?? '';
                      final fotoUrl = m['fotoUrl'] as String?;
                      final lat = (m['lat'] as num?)?.toDouble();
                      final lng = (m['lng'] as num?)?.toDouble();
                      final horarios = m['horarios'] as Map<String, dynamic>?;

                      final subt = [
                        if (ciudad.isNotEmpty) ciudad,
                        if (provincia.isNotEmpty) provincia,
                      ].join(' • ');

                      double? distanciaKm;
                      if ((_fCerca || _ordenDist) && _lat != null && _lng != null && lat != null && lng != null) {
                        distanciaKm = _distKm(_lat!, _lng!, lat, lng);
                      }

                      final abierto = isOpenNow(horarios);
                      final tienePromo = _comerciosConPromo.contains(doc.id);

                      return CommerceTile(
                        title: nombre.isEmpty ? 'Sin nombre' : nombre,
                        subtitle: subt,
                        imageUrl: fotoUrl,
                        isOpen: abierto,
                        hasPromo: tienePromo,
                        distanceKm: distanciaKm,
                        isFavorite: _favs.contains(doc.id),
                        onToggleFavorite: () => _toggleFav(doc.id),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ComercioDetallePage(comercioId: doc.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ================== Widgets auxiliares ================== */

class _ChipToggle extends StatelessWidget {
  const _ChipToggle({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        ),
      ),
      selectedColor: cs.primaryContainer.withOpacity(.55),
      backgroundColor: cs.surfaceContainerHighest.withOpacity(.45),
      shape: StadiumBorder(
        side: BorderSide(color: cs.outlineVariant.withOpacity(.35)),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
