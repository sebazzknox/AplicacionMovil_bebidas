import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

/// ─────────────────────────────────────────────────────────────────────────────
/// CONFIGURACIÓN CLOUDINARY (reemplazá con tus datos)
///   kCloudinaryUploadUrl: https://api.cloudinary.com/v1_1/<tu_cloud_name>/image/upload
///   kCloudinaryUploadPreset: <tu_unsigned_upload_preset>
/// ─────────────────────────────────────────────────────────────────────────────
const String kCloudinaryUploadUrl =
    'https://api.cloudinary.com/v1_1/dlk7onebj/image/upload';
const String kCloudinaryUploadPreset = 'mi_default';

class AdminNewPromoPage extends StatefulWidget {
  const AdminNewPromoPage({super.key});

  @override
  State<AdminNewPromoPage> createState() => _AdminNewPromoPageState();
}

class _AdminNewPromoPageState extends State<AdminNewPromoPage> {
  final _formKey = GlobalKey<FormState>();

  final _comercioIdCtrl = TextEditingController();
  final _comercioNombreCtrl = TextEditingController();
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _precioOriginalCtrl = TextEditingController();
  final _precioOfertaCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();

  DateTime? _hasta;
  bool _saving = false;
  bool _uploadingImage = false;

  @override
  void dispose() {
    _comercioIdCtrl.dispose();
    _comercioNombreCtrl.dispose();
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _precioOriginalCtrl.dispose();
    _precioOfertaCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  double? _toDouble(String v) {
    if (v.trim().isEmpty) return null;
    return double.tryParse(v.replaceAll(',', '.'));
  }

  Future<void> _pickHasta() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _hasta ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Seleccioná la fecha de fin',
    );
    if (picked != null) {
      setState(() => _hasta =
          DateTime(picked.year, picked.month, picked.day, 23, 59));
    }
  }

  Future<void> _chooseComercio() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String query = '';
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return StatefulBuilder(builder: (context, setSt) {
              final stream = FirebaseFirestore.instance
                  .collection('comercios')
                  .orderBy('nombre')
                  .limit(200)
                  .snapshots();

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Text('Elegir comercio',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar por nombre',
                      ),
                      onChanged: (v) =>
                          setSt(() => query = v.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: stream,
                        builder: (_, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final all = snap.data?.docs ?? [];
                          final filtered = all.where((doc) {
                            final n = (doc.data()['nombre'] ?? '')
                                .toString()
                                .toLowerCase();
                            return query.isEmpty || n.contains(query);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(child: Text('Sin resultados'));
                          }

                          return ListView.separated(
                            controller: controller,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final d = filtered[i];
                              final nombre = (d.data()['nombre'] ?? 'Comercio')
                                  .toString();
                              return ListTile(
                                leading: const Icon(
                                    Icons.store_mall_directory_outlined),
                                title: Text(nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(d.id),
                                onTap: () => Navigator.pop(
                                    ctx, {'id': d.id, 'nombre': nombre}),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            });
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _comercioIdCtrl.text = result['id'] ?? '';
        _comercioNombreCtrl.text = result['nombre'] ?? '';
      });
    }
  }

  Future<void> _pickImageAndUpload() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() => _uploadingImage = true);

      final url = await _uploadToCloudinary(picked);
      if (url != null) {
        _imageUrlCtrl.text = url;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Imagen subida a Cloudinary ✅')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No se pudo subir la imagen')));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<String?> _uploadToCloudinary(XFile file) async {
    final uri = Uri.parse(kCloudinaryUploadUrl);
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = kCloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final res = await req.send();
    if (res.statusCode == 200) {
      final body = await res.stream.bytesToString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['secure_url'] ?? json['url']) as String?;
    }
    return null;
  }

  Future<void> _save() async {
  final cs = Theme.of(context).colorScheme;

  if (!_formKey.currentState!.validate()) return;
  if (_hasta == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Elegí la fecha de fin'), backgroundColor: cs.error),
    );
    return;
  }

  setState(() => _saving = true);
  try {
    final comercioId      = _comercioIdCtrl.text.trim();
    final comercioNombre  = _comercioNombreCtrl.text.trim();
    final titulo          = _tituloCtrl.text.trim();
    final descripcion     = _descCtrl.text.trim();
    final precioOriginal  = _toDouble(_precioOriginalCtrl.text);
    final precioOferta    = _toDouble(_precioOfertaCtrl.text);
    final imageUrl        = _imageUrlCtrl.text.trim();

    final ahora  = DateTime.now();
    final inicio = ahora;
    final fin    = _hasta!; // ya viene con 23:59
    final activa = ahora.isBefore(fin);

    // Payload UNIFICADO (campos duplicados para compatibilidad con listados)
    final data = <String, dynamic>{
      'comercioId'     : comercioId,
      'comercioNombre' : comercioNombre,
      'titulo'         : titulo,
      'descripcion'    : descripcion,

      // imagen: ambos nombres
      'fotoUrl'        : imageUrl,
      'img'            : imageUrl,

      // precios (opcionales)
      'precioOriginal' : precioOriginal,
      'precioOferta'   : precioOferta,

      // fechas: ambos nombres
      'inicio'         : Timestamp.fromDate(inicio),
      'desde'          : Timestamp.fromDate(inicio),
      'fin'            : Timestamp.fromDate(fin),
      'hasta'          : Timestamp.fromDate(fin),

      // estados
      'activa'         : activa,
      'destacada'      : true,
      'visible'        : true,
      'estado'         : activa ? 'activa' : 'vencida',

      // metadatos
      'createdAt'      : FieldValue.serverTimestamp(),
      'updatedAt'      : FieldValue.serverTimestamp(),
    };

    // 1) Crear en colección GLOBAL
    final ref = await FirebaseFirestore.instance.collection('ofertas').add(data);

    // 2) Duplicar en subcolección del comercio (mismo ID para sincronía)
    if (comercioId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('comercios')
          .doc(comercioId)
          .collection('ofertas')
          .doc(ref.id)
          .set({
        ...data,
        'ofertaId': ref.id, // referencia cruzada
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo publicada ✅')),
      );
      Navigator.pop(context);
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al publicar: $e')),
    );
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva promo'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // COMERCIO (solo lectura + picker)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _comercioIdCtrl,
                          readOnly: true,
                          onTap: _chooseComercio,
                          decoration: const InputDecoration(
                            labelText: 'Comercio ID *',
                            hintText: 'p.ej. abc123',
                            prefixIcon:
                                Icon(Icons.store_mall_directory_outlined),
                            suffixIcon: Icon(Icons.search),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Requerido'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _comercioNombreCtrl,
                          readOnly: true,
                          onTap: _chooseComercio,
                          decoration: const InputDecoration(
                            labelText: 'Comercio nombre *',
                            hintText: 'p.ej. Kiosko 23',
                            suffixIcon: Icon(Icons.search),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Requerido'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _tituloCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título *',
                      hintText: 'p.ej. 2x1 en cervezas',
                      prefixIcon: Icon(Icons.local_offer_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _descCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Detalles de la promo',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _precioOriginalCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Precio original',
                            prefixText: '\$ ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _precioOfertaCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Precio oferta',
                            prefixText: '\$ ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: cs.secondaryContainer,
                      child: Icon(Icons.event, color: cs.onSecondaryContainer),
                    ),
                    title: const Text('Válida hasta *'),
                    subtitle: Text(
                      _hasta == null
                          ? 'Sin elegir'
                          : '${_hasta!.day.toString().padLeft(2, '0')}/'
                            '${_hasta!.month.toString().padLeft(2, '0')}/'
                            '${_hasta!.year}',
                    ),
                    trailing: FilledButton.icon(
                      onPressed: _pickHasta,
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Elegir'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // URL + SUBIR IMAGEN
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _imageUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'URL imagen (Cloudinary)',
                            hintText:
                                'https://res.cloudinary.com/.../image/upload/...',
                            prefixIcon: Icon(Icons.image_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _uploadingImage ? null : _pickImageAndUpload,
                        icon: _uploadingImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.file_upload_outlined),
                        label: const Text('Subir'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _ImagePreviewField(controller: _imageUrlCtrl),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Publicar'),
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

class _ImagePreviewField extends StatefulWidget {
  final TextEditingController controller;
  const _ImagePreviewField({required this.controller});

  @override
  State<_ImagePreviewField> createState() => _ImagePreviewFieldState();
}

class _ImagePreviewFieldState extends State<_ImagePreviewField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final url = widget.controller.text.trim();
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Previsualización',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: url.isEmpty
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primaryContainer, cs.surface],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child:
                        Icon(Icons.image, color: cs.onPrimaryContainer, size: 36),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: cs.surface,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, size: 36),
                    ),
                    loadingBuilder: (c, w, prog) => prog == null
                        ? w
                        : Container(
                            color: cs.surface,
                            alignment: Alignment.center,
                            child:
                                const CircularProgressIndicator(strokeWidth: 2),
                          ),
                  ),
          ),
        ),
      ],
    );
  }
}