import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'comercio_detalle_page.dart';
import 'bebidas_page.dart'; // 👈 para abrir el CRUD de bebidas
import 'admin_state.dart'; // 👈 NUEVO: estado global de admin

// Podés dejar este flag para "forzar" admin en dev si querés.
// Con el login real, adminMode.value manda. Usamos (kIsAdmin || isAdmin).
 bool kIsAdmin = false;

class ComerciosPage extends StatefulWidget {
  const ComerciosPage({super.key});

  @override
  State<ComerciosPage> createState() => _ComerciosPageState();
}

class _ComerciosPageState extends State<ComerciosPage> {
  final _busquedaCtrl = TextEditingController();
  String _query = '';

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
    final comerciosCol = FirebaseFirestore.instance.collection('comercios');

    // 👇 Escuchamos cambios del modo admin (login/logout) sin perder nada de tu UI
    return ValueListenableBuilder<bool>(
      valueListenable: adminMode,
      builder: (context, isAdmin, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Lugares de venta de bebidas')),
          body: Column(
            children: [
              // Caja de búsqueda
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _busquedaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Provincia, ciudad o comercio',
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

              // Lista de comercios
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: comerciosCol.orderBy('nombre').snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }
                    final docs = snap.data?.docs ?? [];

                    // Filtro simple en cliente por ahora
                    final q = _query;
                    final filtrados = q.isEmpty
                        ? docs
                        : docs.where((d) {
                            final data = d.data();
                            final nombre =
                                (data['nombre'] ?? '').toString().toLowerCase();
                            final ciudad =
                                (data['ciudad'] ?? '').toString().toLowerCase();
                            final provincia =
                                (data['provincia'] ?? '').toString().toLowerCase();
                            return nombre.contains(q) ||
                                ciudad.contains(q) ||
                                provincia.contains(q);
                          }).toList();

                    if (filtrados.isEmpty) {
                      return const Center(
                        child: Text('No hay comercios (o no coinciden con la búsqueda).'),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemBuilder: (context, i) {
                        final doc = filtrados[i];
                        final data = doc.data();
                        final nombre = (data['nombre'] ?? '') as String;
                        final fotoUrl = data['fotoUrl'] as String?;
                        final ciudad = (data['ciudad'] ?? '') as String?;
                        final provincia = (data['provincia'] ?? '') as String?;
                        final subt = [
                          if (ciudad != null && ciudad.isNotEmpty) ciudad,
                          if (provincia != null && provincia.isNotEmpty) provincia,
                        ].join(' • ');

                        return Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 0.5,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              // 👉 Navegamos al detalle público del comercio
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ComercioDetallePage(
                                    comercioId: doc.id,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 70,
                                      height: 70,
                                      child: (fotoUrl == null || fotoUrl.isEmpty)
                                          ? Container(
                                              color: Colors.black12,
                                              child: const Icon(Icons.storefront, size: 32),
                                            )
                                          : Image.network(fotoUrl, fit: BoxFit.cover),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nombre,
                                          style: Theme.of(context).textTheme.titleMedium,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        if (subt.isNotEmpty)
                                          Text(
                                            subt,
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        if (kIsAdmin || isAdmin)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(
                                              'ADMIN',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(color: Colors.deepPurple),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // 👉 Acciones
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Botón gestionar (CRUD) sólo para admin
                                      if (kIsAdmin || isAdmin)
                                        IconButton(
                                          tooltip: 'Gestionar bebidas',
                                          icon: const Icon(Icons.build_circle_outlined),
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
                                              final ok = await _confirmarBorrado(context, nombre);
                                              if (ok) {
                                                await _deleteFotoByPath(data['fotoPath'] as String?);
                                                await doc.reference.delete();
                                              }
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(value: 'edit', child: Text('Editar')),
                                            PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                          ],
                                        ),
                                      const Icon(Icons.chevron_right),
                                    ],
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

          // FAB sólo visible para admin (dinámico o forzado por kIsAdmin)
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

  // ========= Helpers de imagen/Storage =========
  Future<void> _pickFoto(StateSetter setLocal) async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
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
    try { await FirebaseStorage.instance.ref().child(path).delete(); } catch (_) {}
  }

  // ========= Confirmar borrado =========
  Future<bool> _confirmarBorrado(BuildContext context, String nombre) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirmar borrado'),
            content: Text('¿Eliminar "$nombre"? Esta acción no se puede deshacer.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
            ],
          ),
        ) ??
        false;
  }

  // ========= Formulario (crear / editar) =========
  Future<void> _abrirFormComercio({DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final isEdit = doc != null;
    final data   = doc?.data();

    final nombreCtrl    = TextEditingController(text: data?['nombre'] ?? '');
    final ciudadCtrl    = TextEditingController(text: data?['ciudad'] ?? '');
    final provinciaCtrl = TextEditingController(text: data?['provincia'] ?? '');

    String? fotoUrlPreview = data?['fotoUrl'] as String?;
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
                          : (fotoUrlPreview != null && fotoUrlPreview!.isNotEmpty)
                              ? Image.network(fotoUrlPreview!, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.black12,
                                  child: const Icon(Icons.add_a_photo, size: 36),
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

    final nombre    = nombreCtrl.text.trim();
    final ciudad    = ciudadCtrl.text.trim();
    final provincia = provinciaCtrl.text.trim();

    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Poné un nombre')));
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
        } else if ((fotoUrlPreview ?? '').isEmpty && (data?['fotoPath'] != null)) {
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
      setState(() => _fotoTmp = null);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isEdit ? 'Comercio actualizado' : 'Comercio creado')),
    );
  }
}