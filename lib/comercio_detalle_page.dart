import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'bebidas_page.dart';
import 'stock_page.dart';
import 'comercios_page.dart' show kIsAdmin;

// ===================== Helpers generales =====================
Map<String, dynamic>? asMapDynamic(Object? v) {
  if (v == null) return null;
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val));
  }
  return null;
}

List<Map<String, dynamic>> asListMapDynamic(Object? v) {
  if (v is List) {
    return v
        .whereType<Map>()
        .map((e) => e.map((k, val) => MapEntry(k.toString(), val)))
        .toList();
  }
  return const [];
}

String _fmt(String s) => s.trim();

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

// ===================== Página =====================
class ComercioDetallePage extends StatelessWidget {
  final String comercioId;
  const ComercioDetallePage({super.key, required this.comercioId});

  @override
  Widget build(BuildContext context) {
    final docRef =
        FirebaseFirestore.instance.collection('comercios').doc(comercioId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data!.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Comercio')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Comercio no encontrado'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver'),
                  ),
                ],
              ),
            ),
          );
        }

        final nombre = (data['nombre'] ?? '') as String;
        final fotoUrl = data['fotoUrl'] as String?;
        final ciudad = (data['ciudad'] ?? '') as String?;
        final provincia = (data['provincia'] ?? '') as String?;
        final telefono = (data['telefono'] ?? '') as String?;
        final instagram = (data['instagram'] ?? '') as String?;
        final facebook = (data['facebook'] ?? '') as String?;
        final direccion = (data['direccion'] ?? '') as String?;
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();

        final subt = [
          if (ciudad != null && ciudad.isNotEmpty) ciudad,
          if (provincia != null && provincia.isNotEmpty) provincia,
        ].join(' • ');

        final horarios = asMapDynamic(data['horarios']);

        return Scaffold(
          appBar: AppBar(
            title: Text(nombre.isEmpty ? 'Comercio' : nombre),
            actions: [
              IconButton(
                tooltip: 'Compartir',
                icon: const Icon(Icons.share_outlined),
                onPressed: () {
                  final partes = <String>[];
                  partes.add(
                      nombre.isEmpty ? 'Mirá este comercio 👇' : 'Mirá "$nombre" 👇');
                  if (direccion != null && direccion.isNotEmpty) {
                    partes.add('📍 $direccion');
                  }
                  final loc = [
                    if (ciudad != null && ciudad.isNotEmpty) ciudad,
                    if (provincia != null && provincia.isNotEmpty) provincia,
                  ].join(', ');
                  if (loc.isNotEmpty) partes.add('🏙️ $loc');
                  if (telefono != null && telefono.isNotEmpty) partes.add('📞 $telefono');
                  if (instagram != null && instagram.isNotEmpty) partes.add('📸 $instagram');
                  if (facebook != null && facebook.isNotEmpty) partes.add('📘 $facebook');
                  partes.add('\nDescargá la app y encontrá más bebidas cerca 🍻');
                  Share.share(partes.join('\n'));
                },
              ),
              if (kIsAdmin)
                IconButton(
                  tooltip: 'Editar comercio',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editarComercio(context, docRef, data),
                ),
            ],
          ),

          // ======== Body ========
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _HeaderCard(nombre: nombre, subtitulo: subt, fotoUrl: fotoUrl),
              const SizedBox(height: 14),

              _HorariosRow(
                horarios: horarios,
                onVerMas: () => _showHorariosSheet(context, horarios),
              ),
              const SizedBox(height: 10),

              if (direccion != null && direccion.isNotEmpty)
                _GlassCard(
                  child: _InfoTile(
                    icon: Icons.location_on_outlined,
                    title: 'Dirección',
                    subtitle: direccion,
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Abrir mapa'),
                      onPressed: () {
                        final uri = (lat != null && lng != null)
                            ? Uri.parse(
                                'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(nombre)})')
                            : Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(direccion)}');
                        _launchUri(uri);
                      },
                    ),
                  ),
                ),
              if (direccion != null && direccion.isNotEmpty)
                const SizedBox(height: 8),

              // -------- Acciones rápidas --------
              _ActionsGrid(
                telefono: telefono,
                direccion: direccion,
                instagram: instagram,
                facebook: facebook,
                lat: lat,
                lng: lng,
                nombre: nombre,
              ),

              const SizedBox(height: 26),

              // -------- CTAs principales --------
              FilledButton.icon(
                icon: const Icon(Icons.local_drink_outlined),
                label: const Text('Ver bebidas'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BebidasPage(
                        initialComercioId: comercioId,
                        initialComercioNombre: nombre,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Ver stock'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StockPage(
                        comercioId: comercioId,
                        comercioNombre: nombre,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.directions_outlined),
                label: const Text('Cómo llegar'),
                onPressed: () {
                  final uri = (lat != null && lng != null)
                      ? Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng')
                      : Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(direccion ?? nombre)}');
                  _launchUri(uri);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ------- Helpers -------
  static Future<void> _launchUri(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _editarComercio(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> docRef,
    Map<String, dynamic> data,
  ) async {
    final nombreCtrl =
        TextEditingController(text: (data['nombre'] ?? '').toString());
    final ciudadCtrl =
        TextEditingController(text: (data['ciudad'] ?? '').toString());
    final provinciaCtrl =
        TextEditingController(text: (data['provincia'] ?? '').toString());
    final direccionCtrl =
        TextEditingController(text: (data['direccion'] ?? '').toString());
    final telefonoCtrl =
        TextEditingController(text: (data['telefono'] ?? '').toString());
    final instagramCtrl =
        TextEditingController(text: (data['instagram'] ?? '').toString());
    final facebookCtrl =
        TextEditingController(text: (data['facebook'] ?? '').toString());
    final latCtrl = TextEditingController(
        text: (data['lat'] == null) ? '' : data['lat'].toString());
    final lngCtrl = TextEditingController(
        text: (data['lng'] == null) ? '' : data['lng'].toString());

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Editar comercio'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tf(nombreCtrl, 'Nombre', Icons.storefront),
                  _tf(ciudadCtrl, 'Ciudad', Icons.location_city),
                  _tf(provinciaCtrl, 'Provincia', Icons.map_outlined),
                  _tf(direccionCtrl, 'Dirección', Icons.place_outlined),
                  _tf(telefonoCtrl, 'Teléfono', Icons.call_outlined,
                      keyboard: TextInputType.phone),
                  _tf(instagramCtrl, 'Instagram', Icons.camera_alt_outlined),
                  _tf(facebookCtrl, 'Facebook', Icons.facebook_outlined),
                  Row(
                    children: [
                      Expanded(
                        child: _tf(
                          latCtrl,
                          'Lat',
                          Icons.my_location,
                          keyboard: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _tf(
                          lngCtrl,
                          'Lng',
                          Icons.my_location_outlined,
                          keyboard: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await docRef.update({
      'nombre': nombreCtrl.text.trim(),
      'ciudad': ciudadCtrl.text.trim(),
      'provincia': provinciaCtrl.text.trim(),
      'direccion': direccionCtrl.text.trim(),
      'telefono': telefonoCtrl.text.trim(),
      'instagram': instagramCtrl.text.trim(),
      'facebook': facebookCtrl.text.trim(),
      'lat': double.tryParse(latCtrl.text.trim()),
      'lng': double.tryParse(lngCtrl.text.trim()),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Cambios guardados')));
  }

  static Widget _tf(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }
}

// ===================== Widgets de UI =====================

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surfaceContainerHighest.withOpacity(.55),
        border: Border.all(color: cs.outlineVariant.withOpacity(.4)),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String nombre;
  final String subtitulo;
  final String? fotoUrl;
  const _HeaderCard({
    required this.nombre,
    required this.subtitulo,
    required this.fotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: (fotoUrl == null || fotoUrl!.isEmpty)
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.primaryContainer,
                            cs.secondaryContainer,
                          ],
                        ),
                      ),
                    )
                  : Image.network(fotoUrl!, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(.05),
                      Colors.black.withOpacity(.45),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .2,
                    ),
                  ),
                  if (subtitulo.isNotEmpty)
                    Text(
                      subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.92),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(subtitle),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _ChipAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ChipAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer.withOpacity(.45),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: cs.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: cs.onPrimaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionsGrid extends StatelessWidget {
  final String? telefono;
  final String? direccion;
  final String? instagram;
  final String? facebook;
  final double? lat;
  final double? lng;
  final String nombre;

  const _ActionsGrid({
    required this.telefono,
    required this.direccion,
    required this.instagram,
    required this.facebook,
    required this.lat,
    required this.lng,
    required this.nombre,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final twoCols = w >= 360; // simple rwd

    final children = <Widget>[
      if (telefono != null && telefono!.isNotEmpty)
        _ChipAction(
          icon: Icons.call_outlined,
          label: 'Llamar',
          onTap: () => _launch(Uri(scheme: 'tel', path: telefono)),
        ),
      if (telefono != null && telefono!.isNotEmpty)
        _ChipAction(
          icon: FontAwesomeIcons.whatsapp,
          label: 'WhatsApp',
          onTap: () {
            final clean = telefono!.replaceAll(RegExp(r'[^0-9+]'), '');
            _launch(Uri.parse('https://wa.me/$clean'));
          },
        ),
      if ((lat != null && lng != null) ||
          (direccion != null && direccion!.isNotEmpty))
        _ChipAction(
          icon: Icons.map_outlined,
          label: 'Ubicación',
          onTap: () {
            final uri = (lat != null && lng != null)
                ? Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(nombre)})')
                : Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(direccion!)}');
            _launch(uri);
          },
        ),
      if (instagram != null && instagram!.isNotEmpty)
        _ChipAction(
          icon: Icons.camera_alt_outlined,
          label: 'Instagram',
          onTap: () {
            final url = instagram!.startsWith('http')
                ? instagram!
                : 'https://instagram.com/${instagram!.trim()}';
            _launch(Uri.parse(url));
          },
        ),
      if (facebook != null && facebook!.isNotEmpty)
        _ChipAction(
          icon: Icons.facebook_outlined,
          label: 'Facebook',
          onTap: () {
            final url = facebook!.startsWith('http')
                ? facebook!
                : 'https://facebook.com/${facebook!.trim()}';
            _launch(Uri.parse(url));
          },
        ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.start,
      children: children.map((w) {
        return SizedBox(
          width: twoCols ? (MediaQuery.of(context).size.width - 16 * 2 - 10) / 2 : null,
          child: w,
        );
      }).toList(),
    );
  }

  static Future<void> _launch(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// =============== Horarios Row + Sheet =================

class _HorariosRow extends StatelessWidget {
  final Map<String, dynamic>? horarios;
  final VoidCallback onVerMas;
  const _HorariosRow({required this.horarios, required this.onVerMas});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final h = asMapDynamic(horarios) ?? {};
    final rangos = asListMapDynamic(h['rangos']);

    String today = _diaHoyShort();
    String rangoHoy = '';
    if (rangos.isNotEmpty) {
      for (final r in rangos) {
        final dias = r['dias'];
        final hasToday = (dias is List && dias.map((e) => e.toString()).contains(today)) ||
            (dias is String && dias == today);
        if (hasToday) {
          final d = (r['desde'] ?? '').toString();
          final a = (r['hasta'] ?? '').toString();
          rangoHoy = (d.isNotEmpty && a.isNotEmpty) ? '${_fmt(d)} – ${_fmt(a)}' : '';
          break;
        }
      }
    } else if (h.isNotEmpty) {
      final d = (h['desde'] ?? '').toString();
      final a = (h['hasta'] ?? '').toString();
      rangoHoy = (d.isNotEmpty && a.isNotEmpty) ? '${_fmt(d)} – ${_fmt(a)}' : '';
    }

    bool abierto = false;
    if (rangoHoy.contains('–')) {
      final parts = rangoHoy.split('–');
      final now = TimeOfDay.now();
      TimeOfDay? parse(String s) {
        final segs = s.trim().split(':');
        if (segs.length < 2) return null;
        return TimeOfDay(hour: int.tryParse(segs[0]) ?? 0, minute: int.tryParse(segs[1]) ?? 0);
        }
      final d = parse(parts[0]);
      final a = parse(parts[1]);
      if (d != null && a != null) {
        bool afterStart =
            now.hour > d.hour || (now.hour == d.hour && now.minute >= d.minute);
        bool beforeEnd =
            now.hour < a.hour || (now.hour == a.hour && now.minute <= a.minute);
        abierto = afterStart && beforeEnd;
      }
    }

    final badgeColor = abierto ? Colors.green : cs.error;
    final badgeBg = abierto ? Colors.green.withOpacity(.12) : cs.error.withOpacity(.10);
    final badgeText = abierto ? 'Abierto' : 'Cerrado';

    return _GlassCard(
      child: Row(
        children: [
          Icon(Icons.access_time, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: badgeColor.withOpacity(.35)),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rangoHoy.isNotEmpty ? rangoHoy : 'Sin horario para hoy',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onVerMas,
            child: const Text('Ver más'),
          ),
        ],
      ),
    );
  }
}

void _showHorariosSheet(
  BuildContext context,
  Map<String, dynamic>? horarios,
) {
  final cs = Theme.of(context).colorScheme;

  final safe = asMapDynamic(horarios) ?? <String, dynamic>{};
  final rangos = asListMapDynamic(safe['rangos']);

  final items = <Map<String, dynamic>>[];
  if (rangos.isNotEmpty) {
    items.addAll(rangos);
  } else if (safe.isNotEmpty) {
    items.add({
      'desde': safe['desde'],
      'hasta': safe['hasta'],
      'dias': safe['dias'],
    });
  }

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: cs.surface,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Horarios', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),

              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Este comercio aún no cargó horarios.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              else
                ...items.map((r) {
                  final rawDias = r['dias'];
                  String diasTxt = '';
                  if (rawDias is List) {
                    diasTxt = rawDias.map((e) => e.toString()).join(' · ');
                  } else if (rawDias != null) {
                    diasTxt = rawDias.toString();
                  }

                  final desde = (r['desde'] ?? '').toString();
                  final hasta = (r['hasta'] ?? '').toString();

                  return ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(diasTxt.isEmpty ? 'Días' : diasTxt),
                    subtitle: Text(
                      (desde.isNotEmpty && hasta.isNotEmpty)
                          ? '${_fmt(desde)} – ${_fmt(hasta)}'
                          : 'Sin rango',
                    ),
                  );
                }).toList(),

              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}