// comercios_page.dart
import 'dart:async';
import 'dart:math' show sin, cos, atan2, sqrt, pi;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';

import 'comercio_detalle_page.dart';
import 'bebidas_page.dart';

// Flag que ya venías usando
bool kIsAdmin = false;

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
  final _location = Location();
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
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }
      final data = await _location.getLocation();
      _lat = data.latitude;
      _lng = data.longitude;
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
  String _todayAbbr() {
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

  bool _estaAbiertoAhora(Map<String, dynamic>? horarios) {
    if (horarios == null || horarios.isEmpty) return false;

    // Acepta formato simple: {dias:[...], desde:'HH:mm', hasta:'HH:mm'}
    // y también lista de rangos [{dias:..., desde:..., hasta:...}, ...]
    final hoy = _todayAbbr();
    List<Map<String, dynamic>> rangos = [];
    if (horarios['rangos'] is List) {
      rangos = (horarios['rangos'] as List)
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    } else {
      rangos = [horarios.map((k, v) => MapEntry(k.toString(), v))];
    }
    if (rangos.isEmpty) return false;

    TimeOfDay? parse(String s) {
      final p = s.split(':');
      if (p.length < 2) return null;
      return TimeOfDay(hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0);
    }

    bool dayMatches(dynamic rawDias) {
      if (rawDias == null) return true;
      if (rawDias is List) return rawDias.map((e) => e.toString()).contains(hoy);
      if (rawDias is String) return rawDias.toLowerCase().contains(hoy);
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
        if (nowM >= dM && nowM <= hM) return true; // rango normal
      } else {
        if (nowM >= dM || nowM <= hM) return true; // cruza medianoche
      }
    }
    return false;
  }

  // ================== EDITOR SIMPLE DE HORARIO (ADMIN) ==================
  Future<void> _editarHorarioSimple({
    required String comercioId,
    required Map<String, dynamic>? horariosActual,
  }) async {
    // Estado local del diálogo
    const diasOrder = ['lun','mar','mie','jue','vie','sab','dom'];
    final setIni = <String>{};
    String desdeTxt = '09:00', hastaTxt = '18:00';

    // Leer si ya hay horario cargado (simple o primer rango)
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

    Future<void> pick(bool isDesde) async {
      final init = isDesde ? _parseHHmm(desdeTxt) : _parseHHmm(hastaTxt);
      final t = await showTimePicker(context: context, initialTime: init);
      if (t != null) {
        setState(() {
          if (isDesde) {
            desdeTxt = _fmt(t);
          } else {
            hastaTxt = _fmt(t);
          }
        });
      }
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
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
                  Text('Horario de atención', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: diasOrder.map((d) {
                      final sel = diasSel[d]!;
                      return FilterChip(
                        selected: sel,
                        label: Text(d),
                        onSelected: (v) => setLocal(() => diasSel[d] = v),
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
        );
      },
    );

    if (ok != true) return;

    final dias = diasOrder.where((d) => diasSel[d] == true).toList();
    final payload = {
      'dias': dias,
      'desde': desdeTxt,
      'hasta': hastaTxt,
    };

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
      setState(() {}); // refresco para filtro "Abierto ahora"
    }
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Lugares de venta')),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por provincia, ciudad o comercio',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _q = v),
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
                  label: 'Cerca',
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
                  final provincia =
                      (m['provincia'] ?? '').toString().toLowerCase();

                  if (q.isNotEmpty &&
                      !(nombre.contains(q) ||
                          ciudad.contains(q) ||
                          provincia.contains(q))) {
                    return false;
                  }

                  if (_fPromos && !_comerciosConPromo.contains(d.id)) return false;

                  if (_fAbierto) {
                    final horarios =
                        (m['horarios'] as Map<String, dynamic>?) ?? {};
                    if (!_estaAbiertoAhora(horarios)) return false;
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final doc = filtered[i];
                    final m = doc.data();

                    final nombre = (m['nombre'] ?? '') as String? ?? '';
                    final ciudad = (m['ciudad'] ?? '') as String? ?? '';
                    final provincia =
                        (m['provincia'] ?? '') as String? ?? '';
                    final fotoUrl = m['fotoUrl'] as String?;
                    final lat = (m['lat'] as num?)?.toDouble();
                    final lng = (m['lng'] as num?)?.toDouble();
                    final horarios = m['horarios'] as Map<String, dynamic>?;

                    final subt = [
                      if (ciudad.isNotEmpty) ciudad,
                      if (provincia.isNotEmpty) provincia,
                    ].join(' • ');

                    double? distanciaKm;
                    if (_fCerca &&
                        _lat != null &&
                        _lng != null &&
                        lat != null &&
                        lng != null) {
                      distanciaKm = _distKm(_lat!, _lng!, lat, lng);
                    }

                    final abierto = _estaAbiertoAhora(horarios);

                    return Material(
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 0.5,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: _AvatarSquare(url: fotoUrl),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (abierto)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text('Abierto',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        subtitle: (subt.isEmpty)
                            ? null
                            : Text(subt,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (distanciaKm != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer.withOpacity(.45),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${distanciaKm.toStringAsFixed(1)} km',
                                  style: TextStyle(
                                      color: cs.onPrimaryContainer,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ComercioDetallePage(comercioId: doc.id),
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
                      ),
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

  // Admin bottom sheet con acciones rápidas
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
    final bg =
        selected ? cs.primaryContainer.withOpacity(.55) : cs.surfaceVariant.withOpacity(.45);
    final fg = selected ? cs.onPrimaryContainer : cs.onSurfaceVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarSquare extends StatelessWidget {
  const _AvatarSquare({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 48,
        height: 48,
        child: (url == null || url!.isEmpty)
            ? Container(
                color: cs.surfaceVariant.withOpacity(.5),
                child: Icon(Icons.store, color: cs.onSurfaceVariant),
              )
            : Image.network(url!, fit: BoxFit.cover),
      ),
    );
  }
}