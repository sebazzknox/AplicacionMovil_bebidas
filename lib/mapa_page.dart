// lib/mapa_page.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});
  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> with TickerProviderStateMixin {
  final MapController _map = MapController();

  // user location
  ll.LatLng? _userLatLng;
  bool _gettingLoc = false;

  // selección y ruta
  DocumentSnapshot<Map<String, dynamic>>? _selectedDoc;
  List<ll.LatLng> _routePoints = [];
  List<ll.LatLng> _routeAnimPts = [];
  double? _routeKm;
  double? _routeMin;

  // animaciones
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  late final Animation<double> _pulse = Tween(begin: .7, end: 1.3)
      .chain(CurveTween(curve: Curves.easeInOut))
      .animate(_pulseCtrl);

  AnimationController? _routeCtrl; // recorre la línea

  @override
  void initState() {
    super.initState();
    _ensureLocation();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _routeCtrl?.dispose();
    super.dispose();
  }

  /* ========== UBICACIÓN ========== */
  Future<void> _ensureLocation() async {
    if (_userLatLng != null) return;
    setState(() => _gettingLoc = true);
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
      _userLatLng = ll.LatLng(pos.latitude, pos.longitude);
      setState(() {});
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _gettingLoc = false);
    }
  }

  /* ========== RUTEO (OSRM) ========== */
  Future<void> _traceRouteTo(ll.LatLng dest) async {
    await _ensureLocation();
    if (_userLatLng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener tu ubicación')),
      );}
      return;
    }

    final url =
        'https://router.project-osrm.org/route/v1/driving/${_userLatLng!.longitude},${_userLatLng!.latitude};${dest.longitude},${dest.latitude}?overview=full&geometries=polyline&alternatives=false&steps=false';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw Exception('Ruta no disponible');

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) throw Exception('Sin rutas');
      final first = routes.first as Map<String, dynamic>;

      final poly = (first['geometry'] ?? '').toString();
      final distM = (first['distance'] as num?)?.toDouble() ?? 0;
      final duraS = (first['duration'] as num?)?.toDouble() ?? 0;

      final pts = _decodePolyline(poly);
      if (pts.isEmpty) throw Exception('Polyline vacía');

      // animación del “reflejo” recorriendo la línea
      _routeCtrl?.dispose();
      _routeAnimPts = _densify(pts, 320);
      _routeCtrl = AnimationController(
        vsync: this,
        duration: Duration(
          seconds: math.max(8, (distM / 1000).round() * 2),
        ),
      )..addListener(() {
          if (mounted) setState(() {});
        });
      _routeCtrl!.repeat();

      setState(() {
        _routePoints = pts;
        _routeKm = distM / 1000.0;
        _routeMin = duraS / 60.0;
      });

      final b = _boundsFromPoints(pts);
      if (b != null) {
        _map.fitBounds(b,
            options: const FitBoundsOptions(padding: EdgeInsets.all(48)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo trazar la ruta: $e')));
      }
    }
  }

  List<ll.LatLng> _decodePolyline(String poly) {
    if (poly.isEmpty) return [];
    final List<ll.LatLng> res = [];
    int index = 0, lat = 0, lng = 0;

    while (index < poly.length) {
      int b, shift = 0, result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      res.add(ll.LatLng(lat / 1e5, lng / 1e5));
    }
    return res;
  }

  List<ll.LatLng> _densify(List<ll.LatLng> pts, int target) {
    if (pts.length >= target) return pts;
    final res = <ll.LatLng>[];
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      res.add(a);
      // puntos intermedios para suavidad
      const segs = 3;
      for (var k = 1; k <= segs; k++) {
        final t = k / (segs + 1);
        res.add(ll.LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
      }
    }
    res.add(pts.last);
    return res;
  }

  LatLngBounds? _boundsFromPoints(List<ll.LatLng> pts) {
    if (pts.isEmpty) return null;
    double? minLat, maxLat, minLng, maxLng;
    for (final p in pts) {
      minLat = (minLat == null) ? p.latitude : math.min(minLat, p.latitude);
      maxLat = (maxLat == null) ? p.latitude : math.max(maxLat, p.latitude);
      minLng = (minLng == null) ? p.longitude : math.min(minLng, p.longitude);
      maxLng = (maxLng == null) ? p.longitude : math.max(maxLng, p.longitude);
    }
    if ([minLat, maxLat, minLng, maxLng].any((e) => e == null)) return null;
    return LatLngBounds(ll.LatLng(minLat!, minLng!), ll.LatLng(maxLat!, maxLng!));
  }

  void _clearRoute() {
    _routeCtrl?.dispose();
    _routeCtrl = null;
    setState(() {
      _routePoints.clear();
      _routeAnimPts.clear();
      _routeKm = null;
      _routeMin = null;
    });
  }

  // CARTO claro (mantiene estética)
  String get _tileTemplate =>
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

  ll.LatLng? get _movingPoint {
    if (_routeCtrl == null || _routeAnimPts.isEmpty) return null;
    final idx =
        (_routeCtrl!.value * (_routeAnimPts.length - 1)).clamp(0, _routeAnimPts.length - 1).toInt();
    return _routeAnimPts[idx];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de comercios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Mapa: próximamente ✨'))),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ===== MAPA + datos =====
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('comercios')
                .where('lat', isGreaterThan: -90)
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? const [];

              // marcadores de comercios (compactos con burbuja)
              final shopMarkers = <Marker>[
                for (final d in docs)
                  if (d.data()['lat'] != null && d.data()['lng'] != null)
                    Marker(
                      width: 160, // evita overflow del título
                      height: 44,
                      point: ll.LatLng(
                        (d.data()['lat'] as num).toDouble(),
                        (d.data()['lng'] as num).toDouble(),
                      ),
                      child: _ShopMarker(
                        title: (d.data()['nombre'] ?? 'Local').toString(),
                        selected: d.id == _selectedDoc?.id,
                        onTap: () => _openShopSheet(d),
                      ),
                    ),
              ];

              // marcador del usuario con pulso
              final userMarker = (_userLatLng == null)
                  ? const <Marker>[]
                  : <Marker>[
                      Marker(
                        width: 42,
                        height: 42,
                        point: _userLatLng!,
                        child: _PulsingDot(animation: _pulse),
                      ),
                    ];

              // “reflejo” suave sobre la ruta (si hay)
              final glowMarker = (_movingPoint == null)
                  ? const <Marker>[]
                  : <Marker>[
                      Marker(
                        width: 40,
                        height: 40,
                        point: _movingPoint!,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF1E9BFF).withOpacity(.35),
                                Colors.transparent
                              ],
                              stops: const [0.0, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ];

              return FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter:
                      _userLatLng ?? const ll.LatLng(-34.6037, -58.3816),
                  initialZoom: 13,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.all),
                  onTap: (_, __) => setState(() => _selectedDoc = null),
                ),
                children: [
                  // Tiles (CARTO claro)
                  TileLayer(
                    urlTemplate: _tileTemplate,
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.example.bebidas_app',
                    maxZoom: 19,
                  ),

                  // Ruta “Uber-like” (doble línea)
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 8,
                          color: Colors.white.withOpacity(.92),
                        ),
                      ],
                    ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 5,
                          color: const Color(0xFF1E9BFF),
                        ),
                      ],
                    ),

                  // Marcadores
                  MarkerLayer(markers: [
                    ...userMarker,
                    ...glowMarker,
                    ...shopMarkers,
                  ]),
                ],
              );
            },
          ),

          // ===== Botones circulares izquierdos
          Positioned(
            left: 12,
            top: 12,
            child: Column(
              children: [
                _LeftCircleBtn(
                  icon: Icons.near_me_outlined,
                  onTap: () async {
                    await _ensureLocation();
                    if (_userLatLng != null) _map.move(_userLatLng!, 15);
                  },
                ),
                const SizedBox(height: 10),
                _LeftCircleBtn(
                  icon: Icons.tune,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Filtros: próximamente')),
                    );
                  },
                ),
              ],
            ),
          ),

          // Distancia/tiempo de la ruta (pill centrado arriba)
          if (_routeKm != null && _routeMin != null)
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(.90),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.outlineVariant.withOpacity(.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.alt_route, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${_routeKm!.toStringAsFixed(1)} km · ${_routeMin!.round()} min',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Atribución compacta
          Positioned(
            right: 10,
            bottom: 10 + 72,
            child: InkWell(
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
                mode: LaunchMode.externalApplication,
              ),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(.9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
                ),
                child: const Text(
                  '© OpenStreetMap · © CARTO',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),

          // Hint inferior
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(.88),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Tocá un local para ver opciones',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ),

          // FABs laterales (derecha) + “centrar ruta”
          Positioned(
            right: 16,
            bottom: 96,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_routePoints.isNotEmpty) ...[
                  _RoundFab(
                    icon: Icons.close,
                    tooltip: 'Quitar ruta',
                    onTap: _clearRoute,
                  ),
                  const SizedBox(height: 12),
                  _RoundFab(
                    icon: Icons.center_focus_strong,
                    tooltip: 'Centrar ruta',
                    onTap: () {
                      final b = _boundsFromPoints(_routePoints);
                      if (b != null) {
                        _map.fitBounds(b,
                            options: const FitBoundsOptions(
                                padding: EdgeInsets.all(48)));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _RoundFab(
                  icon: Icons.fit_screen_outlined,
                  tooltip: 'Ver todos los locales',
                  onTap: _fitToAll,
                ),
                const SizedBox(height: 12),
                _RoundFab(
                  icon: Icons.my_location_outlined,
                  tooltip: _gettingLoc ? 'Buscando...' : 'Mi ubicación',
                  onTap: () async {
                    await _ensureLocation();
                    if (_userLatLng != null) {
                      _map.move(_userLatLng!, 15);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fitToAll() async {
    final qs = await FirebaseFirestore.instance.collection('comercios').get();
    final pts = <ll.LatLng>[];
    for (final d in qs.docs) {
      final m = d.data();
      final la = (m['lat'] as num?)?.toDouble();
      final ln = (m['lng'] as num?)?.toDouble();
      if (la != null && ln != null) pts.add(ll.LatLng(la, ln));
    }
    if (pts.isEmpty) return;
    final b = _boundsFromPoints(pts);
    if (b == null) return;
    _map.fitBounds(b, options: const FitBoundsOptions(padding: EdgeInsets.all(48)));
  }

  void _openShopSheet(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data()!;
    final nombre = (data['nombre'] ?? 'Local').toString();
    final la = (data['lat'] as num?)?.toDouble();
    final ln = (data['lng'] as num?)?.toDouble();
    final tel = (data['telefono'] ?? '').toString();
    final ig = (data['instagram'] ?? '').toString();
    if (la == null || ln == null) return;

    setState(() => _selectedDoc = d);
    final dest = ll.LatLng(la, ln);
    final mapsLink = 'https://www.google.com/maps/dir/?api=1&destination=$la,$ln';
    final wazeLink = 'https://waze.com/ul?ll=$la,$ln&navigate=yes';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.storefront)),
                  title: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Opciones'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SquareAction(
                      icon: Icons.alt_route,
                      label: 'Cómo llegar',
                      onTap: () {
                        Navigator.pop(ctx);
                        _traceRouteTo(dest);
                      },
                    ),
                    _SquareAction(
                      icon: Icons.map_outlined,
                      label: 'Google Maps',
                      onTap: () {
                        Navigator.pop(ctx);
                        launchUrl(Uri.parse(mapsLink),
                            mode: LaunchMode.externalApplication);
                      },
                    ),
                    _SquareAction(
                      icon: Icons.navigation_outlined,
                      label: 'Waze',
                      onTap: () {
                        Navigator.pop(ctx);
                        launchUrl(Uri.parse(wazeLink),
                            mode: LaunchMode.externalApplication);
                      },
                    ),
                    if (tel.isNotEmpty)
                      _SquareAction(
                        icon: Icons.call_outlined,
                        label: 'Llamar',
                        onTap: () {
                          Navigator.pop(ctx);
                          launchUrl(Uri(scheme: 'tel', path: tel));
                        },
                      ),
                    if (ig.isNotEmpty)
                      _SquareAction(
                        icon: Icons.camera_alt_outlined,
                        label: 'Instagram',
                        onTap: () {
                          Navigator.pop(ctx);
                          final u = ig.startsWith('http') ? ig : 'https://instagram.com/$ig';
                          launchUrl(Uri.parse(u),
                              mode: LaunchMode.externalApplication);
                        },
                      ),
                    _SquareAction(
                      icon: Icons.ios_share,
                      label: 'Copiar link',
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: mapsLink));
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copiado')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* ================== Widgets auxiliares ================== */

class _PulsingDot extends StatelessWidget {
  final Animation<double> animation;
  const _PulsingDot({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: animation.value,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(.20),
                ),
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 6)
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShopMarker extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  const _ShopMarker({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface.withOpacity(.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant.withOpacity(.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.18),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store,
                size: 16, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? cs.onPrimary : cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundFab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundFab({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(icon, color: cs.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}

class _LeftCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _LeftCircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon),
        ),
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SquareAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}