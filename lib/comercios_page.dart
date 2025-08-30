// comercios_page.dart
import 'dart:async';
import 'dart:math' show sin, cos, atan2, sqrt, pi;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'comercio_detalle_page.dart';
import 'bebidas_page.dart';

// Mostrar FAB de "agregar comercio"
bool kIsAdmin = true; // ← ponelo en false si NO sos admin

class ComerciosPage extends StatefulWidget {
  const ComerciosPage({super.key});
  @override
  State<ComerciosPage> createState() => _ComerciosPageState();
}

class _ComerciosPageState extends State<ComerciosPage> {
  // ---------- Filtros/UI ----------
  final _searchCtrl = TextEditingController();
  String _q = '';
  bool _fAbierto = false;
  bool _fCerca = false;
  bool _fPromos = false;

  // ---------- Ubicación ----------
  bool _locBusy = false;
  double? _lat;
  double? _lng;

  // ---------- Promos ----------
  StreamSubscription<QuerySnapshot>? _promoSub;
  final Set<String> _comerciosConPromo = <String>{};

  @override
  void initState() {
    super.initState();
    _listenPromos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _promoSub?.cancel();
    super.dispose();
  }

  // ================== PROMOS ==================
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
        final m = d.data() as Map<String, dynamic>;
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

  // ================== UBICACIÓN ==================
  Future<void> _ensureLocation() async {
    if (_lat != null && _lng != null) return;
    setState(() => _locBusy = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locBusy = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locBusy = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locBusy = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _lat = pos.latitude;
      _lng = pos.longitude;
    } catch (_) {
      // silencioso
    } finally {
      if (mounted) setState(() => _locBusy = false);
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

  // ================== ABIERTO AHORA ==================
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

  // ================== EDITOR HORARIO (ADMIN) ==================
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

    TimeOfDay _parseHHmm(String s) {
      final p = s.split(':');
      return TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p[1]) ?? 0);
    }
    String _fmt(TimeOfDay t) {
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
                Future<void> _pickLocal(bool d) async {
                  final init = _parseHHmm(d ? desdeTxt : hastaTxt);
                  final res = await showTimePicker(context: ctx, initialTime: init);
                  if (res != null) {
                    setLocal(() {
                      if (d) {
                        desdeTxt = _fmt(res);
                      } else {
                        hastaTxt = _fmt(res);
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
                          backgroundColor: cs.surfaceVariant.withOpacity(.45),
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
                            onPressed: () => _pickLocal(true),
                            icon: const Icon(Icons.access_time),
                            label: Text('Desde  $desdeTxt'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickLocal(false),
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
        .collection('comercios')
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

  // ================== CREAR COMERCIO (FAB) ==================
  Future<void> _crearComercioRapido() async {
    final nombreCtrl = TextEditingController();
    final ciudadCtrl = TextEditingController();
    final provCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo comercio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: ciudadCtrl, decoration: const InputDecoration(labelText: 'Ciudad')),
            TextField(controller: provCtrl, decoration: const InputDecoration(labelText: 'Provincia')),
            const SizedBox(height: 8),
            if (_lat != null && _lng != null)
              Text('Se guardará con ubicación actual: '
                  '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final nombre = nombreCtrl.text.trim();
              if (nombre.isEmpty) return;
              final now = FieldValue.serverTimestamp();
              await FirebaseFirestore.instance.collection('comercios').add({
                'nombre': nombre,
                'ciudad': ciudadCtrl.text.trim(),
                'provincia': provCtrl.text.trim(),
                'lat': _lat,
                'lng': _lng,
                'createdAt': now,
                'updatedAt': now,
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Lugares de venta', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: kIsAdmin
          ? FloatingActionButton(
              onPressed: _crearComercioRapido,
              child: const Icon(Icons.add),
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
                _ChipToggle(
                  icon: Icons.near_me_outlined,
                  label: _locBusy ? 'Buscando...' : 'Cerca',
                  selected: _fCerca,
                  onTap: () async {
                    if (!_fCerca) {
                      await _ensureLocation();
                    }
                    if (mounted) setState(() => _fCerca = !_fCerca);
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
                    if (km > 10) return false; // radio 10 km
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No hay comercios para mostrar.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                    if (_fCerca && _lat != null && _lng != null && lat != null && lng != null) {
                      distanciaKm = _distKm(_lat!, _lng!, lat, lng);
                    }

                    final abierto = isOpenNow(horarios);
                    final tienePromo = _comerciosConPromo.contains(doc.id);

                    return _CommerceCard(
                      title: nombre,
                      subtitle: subt,
                      imageUrl: fotoUrl,
                      abierto: abierto,
                      distanciaKm: distanciaKm,
                      promo: tienePromo,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComercioDetallePage(comercioId: doc.id),
                          ),
                        );
                      },
                      onLongPress: kIsAdmin
                          ? () => _showAdminSheet(
                                comercioId: doc.id,
                                comercioNombre: nombre,
                                horariosActual: horarios,
                              )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Admin bottom sheet
  Future<void> _showAdminSheet({
    required String comercioId,
    required String comercioNombre,
    required Map<String, dynamic>? horariosActual,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
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
              ListTile(
                leading: const Icon(Icons.local_drink_outlined),
                title: const Text('Gestionar bebidas'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BebidasPage(
                        initialComercioId: comercioId,
                        initialComercioNombre: comercioNombre,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ================== Widgets auxiliares ==================

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
      backgroundColor: cs.surfaceVariant.withOpacity(.45),
      shape: StadiumBorder(
        side: BorderSide(color: cs.outlineVariant.withOpacity(.35)),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

class _CommerceCard extends StatelessWidget {
  const _CommerceCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.abierto,
    required this.onTap,
    this.onLongPress,
    this.distanciaKm,
    this.promo = false,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final bool abierto;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double? distanciaKm;
  final bool promo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final estadoChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: abierto ? Colors.green.withOpacity(.12) : Colors.red.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (abierto ? Colors.green : Colors.red).withOpacity(.35)),
      ),
      child: Text(
        abierto ? 'Abierto' : 'Cerrado',
        style: TextStyle(
          color: abierto ? Colors.green : Colors.red,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 60,
                height: 60,
                child: (imageUrl == null || imageUrl!.isEmpty)
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [cs.primaryContainer, cs.secondaryContainer],
                          ),
                        ),
                        child: Icon(Icons.store, color: cs.onPrimaryContainer),
                      )
                    : Image.network(imageUrl!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (promo)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.tertiaryContainer.withOpacity(.60),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.local_offer_outlined, size: 14, color: cs.onTertiaryContainer),
                              const SizedBox(width: 4),
                              Text('Promo',
                                  style: TextStyle(
                                    color: cs.onTertiaryContainer,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.0,
                                  )),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14.0),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                estadoChip,
                if (distanciaKm != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${distanciaKm!.toStringAsFixed(1)} km',
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}