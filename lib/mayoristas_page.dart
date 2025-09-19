// lib/mayoristas_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show sin, cos, atan2, sqrt, pi;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

import 'mayorista_detalle_page.dart';
import 'widgets/commerce_tile.dart';
import 'admin_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ⬇️ Para mini-mapa y geocodificación
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:http/http.dart' as http;

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
      _file = File('${dir.path}/favs_mayoristas.json');
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
  // ---------- Admin (desde Firestore) ----------
  bool _isAdminDoc = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

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
        final byBool = (m['isAdmin'] ?? false) == true;
        final byRole = (m['role'] ?? '') == 'admin';
        if (mounted) setState(() => _isAdminDoc = byBool || byRole);
      });
    });
  }

  // ---------- Filtros/UI ----------
  final _searchCtrl = TextEditingController();
  String _q = '';
  bool _fAbierto = false;
  bool _fCerca = false;
  bool _ordenDist = false; // ordenar por distancia
  bool _fPromos = false;   // se usa sólo si hay promos de mayoristas

  // ---------- Ubicación ----------
  bool _locBusy = false;
  double? _lat;
  double? _lng;

  // Radio de “Cerca”
  double _radioKm = 10;

  // ---------- Promos (si existieran para mayoristas) ----------
  StreamSubscription<QuerySnapshot>? _promoSub;
  final Set<String> _mayoristasConPromo = <String>{};

  // ---------- Favoritos ----------
  final _favStore = _FavStore();
  Set<String> _favs = {};

  // Tiles para mini-map
  static const String _cartoTiles =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

  @override
  void initState() {
    super.initState();
    _watchAdmin();
    _listenPromos();
    _initFavs();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
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

  /* ================== PROMOS (opcional) ================== */
  void _listenPromos() {
    // Si en tu colección global de ofertas guardás promos para mayoristas,
    // dejá un campo 'mayoristaId' que apunte al documento de mayorista.
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
        final id = (m['mayoristaId'] ?? '').toString();
        if (id.isNotEmpty) s.add(id);
      }
      if (mounted) {
        setState(() {
          _mayoristasConPromo
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
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
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

  /* ================== EDITOR HORARIO (ADMIN) ================== */
  Future<void> _editarHorarioSimple({
    required String comercioId,
    required Map<String, dynamic>? horariosActual,
  }) async {
    const diasOrder = ['lun','mar','mie','jue','vie','sab','dom'];
    final setIni = <String>{};
    String desdeTxt = '09:00', hastaTxt = '18:00';

    if (horariosActual != null && horariosActual.isNotEmpty) {
      Map<String, dynamic> base = {};
      if (horariosActual['rangos'] is List && (horariosActual['rangos'] as List).isNotEmpty) {
        final r = (horariosActual['rangos'] as List).first;
        if (r is Map) base = r.map((k, v) => MapEntry(k.toString(), v));
      } else {
        base = horariosActual.map((k, v) => MapEntry(k.toString(), v));
      }
      final rawDias = base['dias'];
      if (rawDias is List) {
        setIni.addAll(rawDias.map((e) => e.toString()));
      } else if (rawDias is String) {
        for (final d in diasOrder) {
          if (rawDias.toLowerCase().contains(d)) setIni.add(d);
        }
      }
      desdeTxt = (base['desde'] ?? desdeTxt).toString();
      hastaTxt = (base['hasta'] ?? hastaTxt).toString();
    }

    final diasSel = {for (final d in diasOrder) d: setIni.contains(d)};

    TimeOfDay parseHHmm(String s) {
      final p = s.split(':');
      return TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p[1]) ?? 0);
    }
    String fmt(TimeOfDay t) {
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        final cs = Theme.of(context).colorScheme;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 8,
            ),
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                Future<void> pickLocal(bool d) async {
                  final init = parseHHmm(d ? desdeTxt : hastaTxt);
                  final res = await showTimePicker(context: ctx, initialTime: init);
                  if (res != null) {
                    setLocal(() {
                      if (d) {
                        desdeTxt = fmt(res);
                      } else {
                        hastaTxt = fmt(res);
                      }
                    });
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Horario de atención',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: diasOrder.map((d) {
                        final sel = diasSel[d]!;
                        return ChoiceChip(
                          selected: sel,
                          label: Text(d),
                          onSelected: (v) => setLocal(() => diasSel[d] = v),
                          selectedColor: cs.primaryContainer.withOpacity(.55),
                          backgroundColor: cs.surfaceContainerHighest.withOpacity(.45),
                          shape: StadiumBorder(
                            side: BorderSide(color: cs.outlineVariant.withOpacity(.35)),
                          ),
                          labelStyle: TextStyle(
                            color: sel ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickLocal(true),
                            icon: const Icon(Icons.access_time),
                            label: Text('Desde  $desdeTxt'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickLocal(false),
                            icon: const Icon(Icons.access_time),
                            label: Text('Hasta  $hastaTxt'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(ctx, true),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (ok != true) return;

    final dias = diasSel.entries.where((e) => e.value).map((e) => e.key).toList();
    final payload = {'dias': dias, 'desde': desdeTxt, 'hasta': hastaTxt};

    await FirebaseFirestore.instance
        .collection('mayoristas')
        .doc(comercioId)
        .update({
      'horarios': payload,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Horario guardado')));
      setState(() {});
    }
  }

  /* ================== CREAR MAYORISTA (FAB) ================== */
  Future<void> _crearMayoristaRapido() async {
    final nombreCtrl = TextEditingController();
    final ciudadCtrl = TextEditingController();
    final provCtrl = TextEditingController();
    final dirCtrl = TextEditingController();

    double? lat;
    double? lng;
    bool buscando = false;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          title: const Text('Nuevo mayorista'),
          // ⬇️ Clave para evitar los errores de IntrinsicWidth/Height
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  TextField(
                    controller: ciudadCtrl,
                    decoration: const InputDecoration(labelText: 'Ciudad'),
                  ),
                  TextField(
                    controller: provCtrl,
                    decoration: const InputDecoration(labelText: 'Provincia'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: dirCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dirección (calle, número, ciudad)',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.search),
                        label: Text(buscando ? 'Buscando...' : 'Buscar dirección'),
                        onPressed: buscando
                            ? null
                            : () async {
                                final q = dirCtrl.text.trim();
                                if (q.isEmpty) return;
                                setLocal(() => buscando = true);
                                final res = await _geocodeAddress(q);
                                setLocal(() => buscando = false);
                                if (res == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No se encontró la dirección')),
                                    );
                                  }
                                  return;
                                }
                                setLocal(() {
                                  lat = (res['lat'] as num).toDouble();
                                  lng = (res['lng'] as num).toDouble();
                                });
                              },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Elegir en mapa'),
                        onPressed: () async {
                          final picked = await _openMiniMapPicker(
                            init: (lat != null && lng != null) ? ll.LatLng(lat!, lng!) : null,
                          );
                          if (picked != null) {
                            setLocal(() {
                              lat = picked.latitude;
                              lng = picked.longitude;
                            });
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.my_location),
                        label: const Text('Usar mi ubicación'),
                        onPressed: () async {
                          final pos = await _getCurrentPosition();
                          if (pos == null) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No se pudo obtener la ubicación')),
                              );
                            }
                            return;
                          }
                          setLocal(() {
                            lat = pos.latitude;
                            lng = pos.longitude;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      (lat != null && lng != null)
                          ? 'Ubicación: ${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}'
                          : 'Ubicación: (sin definir)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (lat != null && lng != null)
                    SizedBox(
                      height: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: ll.LatLng(lat!, lng!),
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: _cartoTiles,
                              subdomains: const ['a', 'b', 'c', 'd'],
                              userAgentPackageName: 'com.descabio.app',
                            ),
                            MarkerLayer(markers: [
                              Marker(
                                point: ll.LatLng(lat!, lng!),
                                width: 40,
                                height: 40,
                                child: Icon(Icons.location_on,
                                    color: Theme.of(ctx).colorScheme.primary, size: 36),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(), // usa el ctx del diálogo
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                if (nombre.isEmpty) return;
                final now = FieldValue.serverTimestamp();
                await FirebaseFirestore.instance.collection('mayoristas').add({
                  'nombre': nombre,
                  'ciudad': ciudadCtrl.text.trim(),
                  'provincia': provCtrl.text.trim(),
                  if (lat != null) 'lat': lat,
                  if (lng != null) 'lng': lng,
                  'createdAt': now,
                  'updatedAt': now,
                });
                if (context.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  // === Geocodificación simple con Nominatim ===
  Future<Map<String, dynamic>?> _geocodeAddress(String query) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeComponent(query)}');
      final res = await http.get(uri, headers: {
        'User-Agent': 'Descabio/1.0 (contact: app)',
      });
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) return null;
      final m = list.first as Map<String, dynamic>;
      final lat = double.tryParse((m['lat'] ?? '').toString());
      final lon = double.tryParse((m['lon'] ?? '').toString());
      if (lat == null || lon == null) return null;
      return {'lat': lat, 'lng': lon, 'display': (m['display_name'] ?? '').toString()};
    } catch (_) {
      return null;
    }
  }

  // === Picker en pantalla completa (evita “sheet” en blanco)
  Future<ll.LatLng?> _openMiniMapPicker({ll.LatLng? init}) async {
    return Navigator.of(context).push<ll.LatLng>(
      MaterialPageRoute(builder: (_) => _PickOnMapPage(initial: init)),
    );
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
              subtitle: Text('Filtrar mayoristas por distancia'),
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

    final isAdminUI = _isAdminDoc || AdminState.isAdmin(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Mayoristas', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: isAdminUI
          ? FloatingActionButton(
              onPressed: _crearMayoristaRapido,
              child: const Icon(Icons.add_business),
            )
          : null,
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
                  hintText: 'Buscar por provincia, ciudad o mayorista',
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
                // Long-press para elegir radio
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
                if (_mayoristasConPromo.isNotEmpty)
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
                  .collection('mayoristas')
                  .orderBy('nombre')
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

                  if (_fPromos && !_mayoristasConPromo.contains(d.id)) return false;

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
                    if (km > _radioKm) return false; // ← usa el radio elegido
                  }

                  return true;
                }).toList();

                // Orden por distancia (si tenemos user loc)
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
                      final tienePromo = _mayoristasConPromo.contains(doc.id);

                      return CommerceTile(
                        title: nombre.isEmpty ? 'Sin nombre' : nombre,
                        subtitle: subt,
                        imageUrl: fotoUrl,
                        isOpen: abierto,
                        hasPromo: tienePromo,
                        distanceKm: distanciaKm,
                        // ❤️ favoritos
                        isFavorite: _favs.contains(doc.id),
                        onToggleFavorite: () => _toggleFav(doc.id),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MayoristaDetallePage(mayoristaId: doc.id),
                            ),
                          );
                        },
                        onLongPress: AdminState.isAdmin(context)
                            ? () => _showAdminSheet(
                                  comercioId: doc.id,
                                  comercioNombre: nombre,
                                  horariosActual: horarios,
                                )
                            : null,
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

  // ======= Admin bottom sheet (con eliminar mayorista) =======
  Future<void> _showAdminSheet({
    required String comercioId,
    required String comercioNombre,
    required Map<String, dynamic>? horariosActual,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Editar horario'),
                onTap: () async {
                  Navigator.pop(context);
                  await _editarHorarioSimple(
                    comercioId: comercioId,
                    horariosActual: horariosActual,
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text('Eliminar mayorista', style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmarEliminarMayorista(
                    comercioId: comercioId,
                    nombre: comercioNombre.isEmpty ? 'Este mayorista' : comercioNombre,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ======= Confirmación y borrado en cascada =======
  Future<void> _confirmarEliminarMayorista({
    required String comercioId,
    required String nombre,
  }) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eliminar mayorista'),
            content: Text(
              '¿Eliminar “$nombre”? Se borrarán horarios y datos relacionados. '
              'Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    try {
      await _deleteMayoristaCascade(comercioId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mayorista eliminado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  Future<void> _deleteMayoristaCascade(String cid) async {
    final fs = FirebaseFirestore.instance;
    final docRef = fs.collection('mayoristas').doc(cid);

    // Borrar archivos en Storage si guardás rutas
    try {
      final snap = await docRef.get();
      final data = snap.data();
      final paths = <String>[
        if ((data?['fotoPath'] ?? '').toString().isNotEmpty) data!['fotoPath'],
        if ((data?['logoPath'] ?? '').toString().isNotEmpty) data!['logoPath'],
        if ((data?['bannerPath'] ?? '').toString().isNotEmpty) data!['bannerPath'],
      ];
      for (final p in paths) {
        try {
          await FirebaseStorage.instance.ref().child(p).delete();
        } catch (_) {}
      }
    } catch (_) {}

    // Subcolecciones del mayorista (si las tuvieras)
    await _deleteCollection(docRef.collection('horarios'));
    await _deleteCollection(docRef.collection('bebidas'));
    await _deleteCollection(docRef.collection('stock'));
    await _deleteCollection(docRef.collection('ofertas')); // si existe

    // Ofertas globales que referencian a este mayorista
    try {
      while (true) {
        final q = await fs
            .collection('ofertas')
            .where('mayoristaId', isEqualTo: cid)
            .limit(50)
            .get();
        if (q.docs.isEmpty) break;
        final batch = fs.batch();
        for (final d in q.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (_) {}

    // Doc del mayorista
    await docRef.delete();
  }

  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> ref,
      {int batchSize = 50}) async {
    QuerySnapshot<Map<String, dynamic>> q;
    do {
      q = await ref.limit(batchSize).get();
      if (q.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in q.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } while (q.docs.length == batchSize);
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

/* ================== Página de selección en mapa ================== */
class _PickOnMapPage extends StatefulWidget {
  final ll.LatLng? initial;
  const _PickOnMapPage({this.initial});

  @override
  State<_PickOnMapPage> createState() => _PickOnMapPageState();
}

class _PickOnMapPageState extends State<_PickOnMapPage> {
  final _ctrl = MapController();
  ll.LatLng? _point;
  bool _locating = false;

  static const String _tileUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
    if (_point == null) _ensureLoc();
  }

  Future<void> _ensureLoc() async {
    setState(() => _locating = true);
    try {
      final service = await Geolocator.isLocationServiceEnabled();
      if (!service) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      if (perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _point = ll.LatLng(pos.latitude, pos.longitude);
      });
      if (_point != null) {
        _ctrl.move(_point!, 15);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final init = _point ?? const ll.LatLng(-34.6037, -58.3816);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegí la ubicación'),
        actions: [
          TextButton.icon(
            onPressed: _point == null
                ? null
                : () => Navigator.pop(context, _point),
            icon: const Icon(Icons.check),
            label: const Text('Confirmar'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _ctrl,
            options: MapOptions(
              initialCenter: init,
              initialZoom: 14,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
              onTap: (_, p) => setState(() => _point = p),
              onLongPress: (_, p) => setState(() => _point = p),
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.descabio.app',
                maxZoom: 19,
              ),
              if (_point != null)
                MarkerLayer(markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: _point!,
                    child: const Icon(Icons.location_on,
                        size: 38, color: Color(0xFF6C4ED2)),
                  ),
                ]),
            ],
          ),

          // Botón mi ubicación
          Positioned(
            bottom: 20,
            right: 16,
            child: Material(
              color: cs.primaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _ensureLoc,
                child: const SizedBox(
                  width: 52, height: 52,
                  child: Icon(Icons.my_location_outlined),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}