import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'bebidas_page.dart';
import 'stock_page.dart'; // 👈 NUEVO: para navegar al stock
import 'comercios_page.dart' show kIsAdmin; // para mostrar/ocultar Editar

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

        return Scaffold(
          appBar: AppBar(
            title: Text(nombre.isEmpty ? 'Comercio' : nombre),
            actions: [
              // 👇 NUEVO: Compartir comercio
              IconButton(
                tooltip: 'Compartir',
                icon: const Icon(Icons.share_outlined),
                onPressed: () {
                  final partes = <String>[];
                  partes.add(nombre.isEmpty ? 'Mirá este comercio 👇' : 'Mirá "$nombre" 👇');
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
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Foto
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: fotoUrl == null || fotoUrl.isEmpty
                      ? Container(
                          color: Colors.black12,
                          child: const Icon(Icons.storefront, size: 64),
                        )
                      : Image.network(fotoUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),

              // Nombre + ciudad/provincia
              Text(
                nombre,
                style: Theme.of(context).textTheme.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subt.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subt, style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (direccion != null && direccion.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(direccion)),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Botones de acción
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (telefono != null && telefono.isNotEmpty)
                    _ActionButton(
                      icon: Icons.call_outlined,
                      label: 'Llamar',
                      onTap: () => _launchUri(Uri(scheme: 'tel', path: telefono)),
                    ),
                  if (telefono != null && telefono.isNotEmpty)
                    _ActionButton(
                      icon: FontAwesomeIcons.whatsapp,
                      label: 'WhatsApp',
                      onTap: () {
                        final telClean =
                            telefono.replaceAll(RegExp(r'[^0-9+]'), '');
                        final url = Uri.parse('https://wa.me/$telClean'); // chat directo
                        _launchUri(url);
                      },
                    ),
                  if (instagram != null && instagram.isNotEmpty)
                    _ActionButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Instagram',
                      onTap: () {
                        final handle = instagram.startsWith('http')
                            ? instagram
                            : 'https://instagram.com/$instagram';
                        _launchUri(Uri.parse(handle));
                      },
                    ),
                  if (facebook != null && facebook.isNotEmpty)
                    _ActionButton(
                      icon: Icons.facebook_outlined,
                      label: 'Facebook',
                      onTap: () {
                        final link = facebook.startsWith('http')
                            ? facebook
                            : 'https://facebook.com/$facebook';
                        _launchUri(Uri.parse(link));
                      },
                    ),
                  if ((lat != null && lng != null) ||
                      (direccion != null && direccion.isNotEmpty))
                    _ActionButton(
                      icon: Icons.map_outlined,
                      label: 'Ubicación',
                      onTap: () {
                        // si hay lat/lng, priorizamos geo URI; si no, buscamos por dirección
                        final uri = (lat != null && lng != null)
                            ? Uri.parse('geo:$lat,$lng?q=$lat,$lng($nombre)')
                            : Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(direccion!)}',
                              );
                        _launchUri(uri);
                      },
                    ),
                ],
              ),

              const SizedBox(height: 24),

              // Ver bebidas del comercio (usa la pantalla que ya hicimos)
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

              // 👇 NUEVO: Ver stock del comercio (visible para todos)
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
            ],
          ),
        );
      },
    );
  }

  // ------- Helpers -------
  static Future<void> _launchUri(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // normalmente mostraría SnackBar desde caller
    }
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: cs.surfaceContainerHighest.withOpacity(.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
