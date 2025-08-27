import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'admin_state.dart';
import 'bebidas_page.dart';
import 'comercio_detalle_page.dart';

// Podés forzar admin en dev. Con el login real, manda adminMode.
bool kIsAdmin = false;

class ComerciosPage extends StatefulWidget {
  const ComerciosPage({super.key});

  @override
  State<ComerciosPage> createState() => _ComerciosPageState();
}

class _ComerciosPageState extends State<ComerciosPage> {
  final _busquedaCtrl = TextEditingController();
  String _query = '';

  // Filtros
  bool _fAbierto = false;
  bool _fCerca = false;
  bool _fPromos = false;

  // Localización
  bool _locBusy = false;
  Position? _pos;

  // Promos (caché en memoria)
  bool _promoBusy = false;
  final Set<String> _promoIds = {};     // ids de comercio
  final Set<String> _promoNames = {};   // nombres de comercio (fallback)

  // Picker y foto temporal (para crear/editar)
  final _picker = ImagePicker();
  XFile? _fotoTmp;

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: adminMode,
      builder: (context, isAdmin, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Lugares de venta')),
          body: Column(
            children: [
              // Buscador
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: TextField(
                  controller: _busquedaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por provincia, ciudad o comercio…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),

              // Filtros (compactos)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      icon: Icons.schedule_outlined,
                      label: 'Abierto ahora',
                      selected: _fAbierto,
                      onTap: () => setState(() => _fAbierto = !_fAbierto),
                    ),
                    _FilterChip(
                      icon: Icons.near_me_outlined,
                      label: _locBusy
                          ? 'Buscando…'
                          : (_pos == null ? 'Cerca' : 'Cerca (≤10 km)'),
                      selected: _fCerca,
                      onTap: () async {
                        if (_pos == null) await _ensureLocation();
                        if (!mounted) return;
                        setState(() => _fCerca = !_fCerca);
                      },
                    ),
                    _FilterChip(
                      icon: Icons.local_offer_outlined,
                      label: _promoBusy ? 'Promos…' : 'Promos',
                      selected: _fPromos,
                      onTap: () async {
                        if (!_fPromos) {
                          // Se va a activar → refresco promos
                          await _refreshPromos();
                        }
                        if (!mounted) return;
                        setState(() => _fPromos = !_fPromos);
                      },
                      tint: cs.tertiaryContainer,
                      iconColor: cs.onTertiaryContainer,
                      fg: cs.onTertiaryContainer,
                    ),
                  ],
                ),
              ),

              // STREAM de comercios
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
                    if (docs.isEmpty) return const _EmptyList();

                    // 1) texto
                    final q = _query;
                    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> items =
                        q.isEmpty
                            ? docs
                            : docs.where((d) {
                                final m = d.data();
                                final nombre =
                                    (m['nombre'] ?? '').toString().toLowerCase();
                                final ciudad =
                                    (m['ciudad'] ?? '').toString().toLowerCase();
                                final provincia =
                                    (m['provincia'] ?? '').toString().toLowerCase();
                                return nombre.contains(q) ||
                                    ciudad.contains(q) ||
                                    provincia.contains(q);
                              });

                    // 2) promos (usa caché)
                    if (_fPromos) {
                      // Si todavía estoy cargando promos, muestro "cargando"
                      if (_promoBusy) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      items = items.where((d) {
                        if (_promoIds.contains(d.id)) return true;
                        final name = (d['nombre'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();
                        return _promoNames.contains(name);
                      });
                    }

                    // 3) abierto ahora
                    if (_fAbierto) {
                      items = items.where((d) => _isOpenNow(d.data()));
                    }

                    // 4) cerca (≤10 km)
                    const radioKm = 10.0;
                    Map<String, double> dists = {};
                    if (_fCerca && _pos != null) {
                      final lat1 = _pos!.latitude;
                      final lon1 = _pos!.longitude;
                      items = items.where((d) {
                        final m = d.data();
                        final lat = (m['lat'] as num?)?.toDouble();
                        final lon = (m['lng'] as num?)?.toDouble();
                        if (lat == null || lon == null) return false;
                        final km = _haversineKm(lat1, lon1, lat, lon);
                        dists[d.id] = km;
                        return km <= radioKm;
                      });
                    }

                    final list = items.toList();
                    if (list.isEmpty) return const _EmptyList();

                    final cs = Theme.of(context).colorScheme;
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 100),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final doc = list[i];
                        final m = doc.data();

                        final nombre = (m['nombre'] ?? '').toString();
                        final fotoStr = (m['fotoUrl'] ?? '').toString();
                        final String? fotoUrl =
                            fotoStr.isEmpty ? null : fotoStr;

                        final ciudad = (m['ciudad'] ?? '').toString();
                        final provincia = (m['provincia'] ?? '').toString();

                        final subt = [
                          if (ciudad.isNotEmpty) ciudad,
                          if (provincia.isNotEmpty) provincia,
                        ].join(' • ');

                        final km = dists[doc.id];

                        return Material(
                          color: cs.surface,
                          elevation: .3,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ComercioDetallePage(comercioId: doc.id),
                                ),
                              );
                            },
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              leading: _AvatarSquare(url: fotoUrl),
                              title: Text(
                                nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: subt.isEmpty ? null : Text(subt),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (km != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainerHighest,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${km.toStringAsFixed(1)} km',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  if (kIsAdmin || isAdmin)
                                    IconButton(
                                      tooltip: 'Gestionar bebidas',
                                      icon:
                                          const Icon(Icons.build_circle_outlined),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => BebidasPage(
                                              initialComercioId: doc.id,
                                              initialComercioNombre: nombre,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  if (kIsAdmin || isAdmin)
                                    PopupMenuButton<String>(
                                      onSelected: (v) async {
                                        if (v == 'edit') {
                                          _abrirFormComercio(doc: doc);
                                        } else if (v == 'delete') {
                                          final ok = await _confirmarBorrado(
                                              context, nombre);
                                          if (ok) {
                                            await _deleteFotoByPath(
                                                m['fotoPath'] as String?);
                                            await doc.reference.delete();
                                          }
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Editar')),
                                        PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Eliminar')),
                                      ],
                                    ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // FAB admin
          floatingActionButton: (kIsAdmin || isAdmin)
              ? FloatingActionButton.extended(
                  onPressed: () => _abrirFormComercio(),
                  icon: const Icon(Icons.add_business),
                  label: const Text('Nuevo comercio'),
                )
              : null,
        );
      },
    );
  }

  // ======== Localización + Haversine ========
  Future<void> _ensureLocation() async {
    setState(() => _locBusy = true);
    try {
      bool service = await Geolocator.isLocationServiceEnabled();
      if (!service) return;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _pos = p;
    } catch (_) {
      // silencioso
    } finally {
      if (mounted) setState(() => _locBusy = false);
    }
  }

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            (math.sin(dLon / 2) * math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double d) => d * (math.pi / 180.0);

  // ======== Abierto ahora (tolerante a formatos) ========
  bool _isOpenNow(Map<String, dynamic> m) {
    final horarios = m['horarios'];
    if (horarios is! List) return false;

    final now = DateTime.now();
    final dow = now.weekday; // 1..7 (1=Lun .. 7=Dom)
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final cur = '$hh:$mm';

    for (final raw in horarios) {
      if (raw is! Map) continue;

      // DÍAS: List<int>, List<String> o String con “lun mar mie …”
      List<int> dias = [];
      final anyDias = raw['dias'];
      if (anyDias is List) {
        dias = anyDias
            .map((e) => _dayToInt(e))
            .where((v) => v != null)
            .cast<int>()
            .toList();
      } else if (anyDias is String) {
        final parts = anyDias
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-záéíóúñ ]'), ' ')
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .toList();
        dias = parts
            .map((e) => _dayToInt(e))
            .where((v) => v != null)
            .cast<int>()
            .toList();
      }
      // Si no vino nada, asumimos todos los días
      if (dias.isEmpty) dias = [1, 2, 3, 4, 5, 6, 7];

      String desde = (raw['desde'] ?? '').toString().trim();
      String hasta = (raw['hasta'] ?? '').toString().trim();

      if (desde.isEmpty && (raw['rango'] ?? '').toString().isNotEmpty) {
        // ejemplo: "22:00 - 23:00"
        final r = (raw['rango'] as String)
            .replaceAll('—', '-')
            .replaceAll('–', '-');
        final p = r.split('-').map((e) => e.trim()).toList();
        if (p.length == 2) {
          desde = p[0];
          hasta = p[1];
        }
      }

      if (dias.contains(dow) && desde.isNotEmpty && hasta.isNotEmpty) {
        if (_timeBetween(cur, desde, hasta)) return true;
      }
    }
    return false;
  }

  // admite rangos cruzando medianoche
  bool _timeBetween(String cur, String from, String to) {
    int m(String t) {
      final p = t.split(':');
      if (p.length != 2) return 0;
      return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
    }
    final c = m(cur), f = m(from), h = m(to);
    if (f <= h) return c >= f && c <= h; // mismo día
    return c >= f || c <= h; // cruza medianoche
  }

  int? _dayToInt(dynamic v) {
    if (v is int) {
      if (v >= 1 && v <= 7) return v;
      return null;
    }
    final s = v.toString().toLowerCase();
    switch (s) {
      case 'lun':
      case 'lunes':
        return 1;
      case 'mar':
      case 'martes':
        return 2;
      case 'mie':
      case 'mié':
      case 'miercoles':
      case 'miércoles':
        return 3;
      case 'jue':
      case 'jueves':
        return 4;
      case 'vie':
      case 'viernes':
        return 5;
      case 'sab':
      case 'sáb':
      case 'sabado':
      case 'sábado':
        return 6;
      case 'dom':
      case 'domingo':
        return 7;
    }
    return null;
  }

  // ======== PROMOS: cargo y cacheo una vez ========
  Future<void> _refreshPromos() async {
    setState(() {
      _promoBusy = true;
      _promoIds.clear();
      _promoNames.clear();
    });
    try {
      final qs = await FirebaseFirestore.instance
          .collection('ofertas')
          .where('activa', isEqualTo: true)
          .get();

      for (final d in qs.docs) {
        final m = d.data();

        // id por distintos nombres de campo
        final id =
            (m['comercioId'] ?? m['storeId'] ?? m['comercioRef'] ?? '').toString();
        if (id.isNotEmpty) _promoIds.add(id);

        // si es DocumentReference
        final ref = m['comercioRef'];
        if (ref is DocumentReference) {
          _promoIds.add(ref.id);
        }

        // nombre por distintos nombres de campo
        final nombre = (m['comercioNombre'] ?? m['comercio'] ?? m['nombreComercio'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (nombre.isNotEmpty) _promoNames.add(nombre);
      }
    } catch (_) {
      // silencioso
    } finally {
      if (mounted) setState(() => _promoBusy = false);
    }
  }

  // ========= Helpers de imagen/Storage =========
  Future<void> _pickFoto(StateSetter setLocal) async {
    final x =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (x != null) setLocal(() => _fotoTmp = x);
  }

  Future<({String url, String path})?> _uploadFoto(String comercioId) async {
    if (_fotoTmp == null) return null;
    final file = File(_fotoTmp!.path);
    final path = 'comercios/$comercioId/foto.jpg';
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    return (url: url, path: path);
  }

  Future<void> _deleteFotoByPath(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref().child(path).delete();
    } catch (_) {}
  }

  // ========= Confirmar borrado =========
  Future<bool> _confirmarBorrado(BuildContext context, String nombre) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirmar borrado'),
            content:
                Text('¿Eliminar "$nombre"? Esta acción no se puede deshacer.'),
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

  // ========= Formulario (crear / editar) =========
  Future<void> _abrirFormComercio(
      {DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final isEdit = doc != null;
    final data = doc?.data();

    final nombreCtrl = TextEditingController(text: data?['nombre'] ?? '');
    final ciudadCtrl = TextEditingController(text: data?['ciudad'] ?? '');
    final provinciaCtrl = TextEditingController(text: data?['provincia'] ?? '');

    String? fotoUrlPreview = (data?['fotoUrl'] ?? '').toString().isEmpty
        ? null
        : (data?['fotoUrl'] as String?);
    _fotoTmp = null;

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
              title: Text(isEdit ? 'Editar comercio' : 'Nuevo comercio'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // preview + selector
                    GestureDetector(
                      onTap: () => _pickFoto(setLocal),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: _fotoTmp != null
                              ? Image.file(File(_fotoTmp!.path), fit: BoxFit.cover)
                              : (fotoUrlPreview != null &&
                                      fotoUrlPreview!.isNotEmpty)
                                  ? Image.network(fotoUrlPreview!, fit: BoxFit.cover)
                                  : Container(
                                      color: Colors.black12,
                                      child:
                                          const Icon(Icons.add_a_photo, size: 36),
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_fotoTmp != null || (fotoUrlPreview ?? '').isNotEmpty)
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
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del comercio',
                        prefixIcon: Icon(Icons.storefront),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ciudadCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ciudad',
                        prefixIcon: Icon(Icons.location_city),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: provinciaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Provincia',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
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

    final nombre = nombreCtrl.text.trim();
    final ciudad = ciudadCtrl.text.trim();
    final provincia = provinciaCtrl.text.trim();

    if (nombre.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Poné un nombre')));
      return;
    }

    final payload = <String, dynamic>{
      'nombre': nombre,
      'ciudad': ciudad,
      'provincia': provincia,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final col = FirebaseFirestore.instance.collection('comercios');

    try {
      if (isEdit) {
        await doc!.reference.update(payload);

        // Nueva foto elegida → subir y reemplazar
        if (_fotoTmp != null) {
          await _deleteFotoByPath(data?['fotoPath'] as String?);
          final up = await _uploadFoto(doc.id);
          if (up != null) {
            await doc.reference.update({'fotoUrl': up.url, 'fotoPath': up.path});
          }
        } else if ((fotoUrlPreview ?? '').isEmpty &&
            (data?['fotoPath'] != null)) {
          // Quitó la foto existente
          await _deleteFotoByPath(data?['fotoPath'] as String?);
          await doc.reference.update({
            'fotoUrl': FieldValue.delete(),
            'fotoPath': FieldValue.delete(),
          });
        }
      } else {
        // Crear
        final newRef = await col.add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (_fotoTmp != null) {
          final up = await _uploadFoto(newRef.id);
          if (up != null) {
            await newRef.update({'fotoUrl': up.url, 'fotoPath': up.path});
          }
        }
      }
    } finally {
      if (mounted) setState(() => _fotoTmp = null);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEdit ? 'Comercio actualizado' : 'Comercio creado')));
  }
}

// ================== Widgets auxiliares ==================

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? tint;
  final Color? iconColor;
  final Color? fg;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.tint,
    this.iconColor,
    this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg =
        selected ? (tint ?? cs.primaryContainer) : cs.surfaceContainerHighest;
    final tc = selected ? (fg ?? cs.onPrimaryContainer) : cs.onSurfaceVariant;
    final ic =
        selected ? (iconColor ?? cs.onPrimaryContainer) : cs.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: ic),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: tc)),
          ],
        ),
      ),
    );
  }
}

class _AvatarSquare extends StatelessWidget {
  final String? url;
  const _AvatarSquare({required this.url});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 56,
        height: 56,
        child: (url == null || url!.isEmpty)
            ? Container(
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.storefront, color: cs.onSurfaceVariant),
              )
            : Image.network(url!, fit: BoxFit.cover),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No hay comercios para mostrar.'),
    );
  }
}