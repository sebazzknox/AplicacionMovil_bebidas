// lib/ofertas_page.dart
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'comercio_detalle_page.dart';
import 'comercios_page.dart' show kIsAdmin; // flag admin

class OfertasPage extends StatefulWidget {
  const OfertasPage({super.key});

  @override
  State<OfertasPage> createState() => _OfertasPageState();
}

class _OfertasPageState extends State<OfertasPage> {
  final _picker = ImagePicker();
  XFile? _fotoTmp;

  // Filtros
  String? _filtroComercioId;
  String? _filtroComercioNombre;
  bool _soloActivas = false;

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('ofertas');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ofertas'),
        actions: [
          if ((_filtroComercioId?.isNotEmpty ?? false) || _soloActivas)
            IconButton(
              tooltip: 'Limpiar filtros',
              onPressed: () => setState(() {
                _filtroComercioId = null;
                _filtroComercioNombre = null;
                _soloActivas = false;
              }),
              icon: const Icon(Icons.filter_alt_off),
            ),
          const SizedBox(width: 4),
        ],
      ),

      body: Column(
        children: [
          // Banner dinámico desde Firestore (si existe/activo)
          const _DynamicBanner(),

          
          
          // Carrusel autoplay (sin índice compuesto)
          const _OfertasCarrusel(),

          // Barra de filtros
          _FiltrosBar(
            filtroComercioNombre: _filtroComercioNombre,
            soloActivas: _soloActivas,
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
          ),

          // Lista
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // Un solo orderBy para evitar índice compuesto
              stream: col.orderBy('fin', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final docsAll = (snap.data?.docs ?? []).toList();

                // Filtros en memoria
                List<DocumentSnapshot<Map<String, dynamic>>> docs = docsAll.where((d) {
                  final data = d.data() ?? {};
                  final activa = (data['activa'] ?? true) == true;
                  final comercioId = data['comercioId'] as String?;
                  if (_soloActivas && !activa) return false;
                  if ((_filtroComercioId?.isNotEmpty ?? false) &&
                      comercioId != _filtroComercioId) return false;
                  return true;
                }).toList();

               if (docs.isEmpty) {
               return _EmptyState(
                title: 'Sin ofertas',
                subtitle: 'No encontramos ofertas para los filtros elegidos.',
                ctaLabel: kIsAdmin ? 'Crear oferta' : null,
                 onCta: kIsAdmin ? () => _abrirFormOferta() : null,
                 );
                 }

                // Reordenar: activas primero, luego por fin desc
                int activeVal(DocumentSnapshot<Map<String, dynamic>> d) =>
                    (d.data()?['activa'] == true) ? 1 : 0;
                DateTime finOf(DocumentSnapshot<Map<String, dynamic>> d) =>
                    (d.data()?['fin'] as Timestamp?)?.toDate() ??
                    DateTime.fromMillisecondsSinceEpoch(0);

                docs.sort((a, b) {
                  final byActive = activeVal(b) - activeVal(a);
                  if (byActive != 0) return byActive;
                  return finOf(b).compareTo(finOf(a));
                });

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data()!;
                    final titulo = (data['titulo'] ?? '') as String;
                    final desc   = (data['descripcion'] ?? '') as String;
                    final foto   = data['fotoUrl'] as String?;
                    final activa = (data['activa'] ?? true) as bool;
                    final comercioId = data['comercioId'] as String?;
                    final finTs = data['fin'] as Timestamp?;
                    final finStr = finTs != null ? _fmtFecha(finTs.toDate()) : '—';

                    return Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 1.0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (comercioId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Esta oferta no tiene un comercio vinculado.')),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ComercioDetallePage(comercioId: comercioId),
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
                                      : Image.network(foto, fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                        if (kIsAdmin)
                                          PopupMenuButton<String>(
                                            onSelected: (v) async {
                                              if (v == 'edit') {
                                                _abrirFormOferta(doc: d);
                                              } else if (v == 'delete') {
                                                final ok = await _confirmarBorrado(context, titulo);
                                                if (ok) {
                                                  await _deleteFotoByPath(data['fotoPath'] as String?);
                                                  await d.reference.delete();
                                                }
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(value: 'edit', child: Text('Editar')),
                                              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (desc.isNotEmpty)
                                      Text(
                                        desc,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: activa
                                                ? Colors.green.withOpacity(.15)
                                                : Colors.grey.withOpacity(.2),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            activa ? 'Activa' : 'Finalizada',
                                            style: Theme.of(context).textTheme.labelSmall,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Hasta $finStr',
                                            style: Theme.of(context).textTheme.bodySmall),
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
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: kIsAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _abrirFormOferta(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva oferta'),
            )
          : null,
    );
  }

  // ---------- Form crear/editar ----------
  Future<void> _abrirFormOferta({DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final isEdit = doc != null;
    final data = doc?.data();

    final tituloCtrl = TextEditingController(text: data?['titulo'] ?? '');
    final descCtrl   = TextEditingController(text: data?['descripcion'] ?? '');

    // Selector de comercio
    String? selectedComercioId   = data?['comercioId'] as String?;
    String? selectedComercioName;

    if (selectedComercioId != null && selectedComercioId.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('comercios').doc(selectedComercioId).get();
        selectedComercioName = (snap.data()?['nombre'] ?? '') as String?;
      } catch (_) {}
    }

    DateTime? inicio = (data?['inicio'] as Timestamp?)?.toDate();
    DateTime? fin    = (data?['fin'] as Timestamp?)?.toDate();
    bool activa      = (data?['activa'] ?? true) as bool;
    bool destacada   = (data?['destacada'] ?? false) as bool;
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
                // Foto
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
                          ? Image.file(File(_fotoTmp!.path), fit: BoxFit.cover)
                          : (fotoUrlPreview != null && fotoUrlPreview!.isNotEmpty)
                              ? Image.network(fotoUrlPreview!, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.black12,
                                  child: const Icon(Icons.add_a_photo, size: 36),
                                ),
                    ),
                  ),
                ),
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

                // Selector de comercio
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await _seleccionarComercio(context);
                    if (picked != null) {
                      setLocal(() {
                        selectedComercioId   = picked['id'];
                        selectedComercioName = picked['nombre'];
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Comercio',
                      prefixIcon: Icon(Icons.store_mall_directory),
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
                        label: Text(inicio == null ? 'Desde' : _fmtFecha(inicio!)),
                        onPressed: () async {
                          final today = DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx,
                            firstDate: DateTime(today.year - 1),
                            lastDate: DateTime(today.year + 3),
                            initialDate: inicio ?? today,
                          );
                          if (picked != null) setLocal(() => inicio = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event),
                        label: Text(fin == null ? 'Hasta' : _fmtFecha(fin!)),
                        onPressed: () async {
                          final today = DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx,
                            firstDate: DateTime(today.year - 1),
                            lastDate: DateTime(today.year + 3),
                            initialDate: fin ?? (inicio ?? today),
                          );
                          if (picked != null) setLocal(() => fin = picked);
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
                      onChanged: (v) => setLocal(() => activa = v),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Destacada (carrusel)'),
                    const Spacer(),
                    Switch(
                      value: destacada,
                      onChanged: (v) => setLocal(() => destacada = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    ) ?? false;

    if (!ok) {
      setState(() => _fotoTmp = null);
      return;
    }

    final titulo = tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta el título')));
      return;
    }

    final payload = <String, dynamic>{
      'titulo': titulo,
      'descripcion': descCtrl.text.trim(),
      'comercioId': (selectedComercioId?.isNotEmpty ?? false) ? selectedComercioId : null,
      'inicio': inicio != null ? Timestamp.fromDate(inicio!) : FieldValue.delete(),
      'fin': fin != null ? Timestamp.fromDate(fin!) : FieldValue.delete(),
      'activa': activa,
      'destacada': destacada,
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
            await doc.reference.update({'fotoUrl': up.url, 'fotoPath': up.path});
          }
        } else if ((fotoUrlPreview ?? '').isEmpty && (data?['fotoPath'] != null)) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Oferta actualizada' : 'Oferta creada')),
      );
    }
  }

  // ---------- Storage ----------
  Future<({String url, String path})?> _uploadFoto(String ofertaId) async {
    if (_fotoTmp == null) return null;
    final path = 'ofertas/$ofertaId/foto.jpg';
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(File(_fotoTmp!.path), SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    return (url: url, path: path);
  }

  Future<void> _deleteFotoByPath(String? path) async {
    if (path == null || path.isEmpty) return;
    try { await FirebaseStorage.instance.ref().child(path).delete(); } catch (_) {}
  }

  // ---------- Utils ----------
  static String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<bool> _confirmarBorrado(BuildContext context, String titulo) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirmar borrado'),
            content: Text('¿Eliminar la oferta "$titulo"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
            ],
          ),
        ) ??
        false;
  }

  // ---------- Selector de comercio ----------
  Future<Map<String, String>?> _seleccionarComercio(BuildContext parentCtx) async {
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
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: col.orderBy('nombre').snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(child: Text('No hay comercios.'));
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final d = docs[i];
                          final data = d.data();
                          final nombre = (data['nombre'] ?? '') as String;
                          final ciudad = (data['ciudad'] ?? '') as String?;
                          final provincia = (data['provincia'] ?? '') as String?;
                          final subt = [
                            if (ciudad != null && ciudad.isNotEmpty) ciudad,
                            if (provincia != null && provincia.isNotEmpty) provincia,
                          ].join(' • ');
                          return ListTile(
                            leading: const Icon(Icons.storefront),
                            title: Text(nombre),
                            subtitle: subt.isEmpty ? null : Text(subt),
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

// ====== Banner dinámico desde Firestore ======
class _DynamicBanner extends StatelessWidget {
  const _DynamicBanner();

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('banners');

    // preferimos doc 'home', si no existe usamos primero activo
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

        // fallback: primer banner activo
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: col.where('activo', isEqualTo: true).limit(1).snapshots(),
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
        aspectRatio: 16 / 9, // misma proporción que tus banners locales
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
                // Texto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (titulo.isNotEmpty)
                        Text(
                          titulo,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (texto.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          texto,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // CTA
                if (ctaUrl.isNotEmpty && ctaLabel.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  FittedBox(
                    child: FilledButton.tonal(
                      onPressed: () async {
                        final uri = Uri.tryParse(ctaUrl);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
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

// ====== Banner local (assets) ======
class _LocalBanner extends StatelessWidget {
  final String imagePath;
  const _LocalBanner({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.asset(imagePath, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

// ====== Carrusel autoplay de ofertas destacadas (sin índice compuesto) ======
class _OfertasCarrusel extends StatefulWidget {
  const _OfertasCarrusel();

  @override
  State<_OfertasCarrusel> createState() => _OfertasCarruselState();
}
class _OfertasCarruselState extends State<_OfertasCarrusel> {
  final _pageCtrl = PageController(viewportFraction: .9);
  Timer? _timer;
  int _idx = 0;

  // 👉 Lista de imágenes locales (asegurate de tenerlas en pubspec.yaml)
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

// ====== Barra de filtros ======
class _FiltrosBar extends StatelessWidget {
  final String? filtroComercioNombre;
  final bool soloActivas;
  final VoidCallback onElegirComercio;
  final ValueChanged<bool> onToggleActivas;

  const _FiltrosBar({
    required this.filtroComercioNombre,
    required this.soloActivas,
    required this.onElegirComercio,
    required this.onToggleActivas,
  });



  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
    );
  }
}

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
            Icon(Icons.local_offer_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.outline),
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