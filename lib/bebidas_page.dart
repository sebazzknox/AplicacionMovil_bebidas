// lib/bebidas_page.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class BebidasPage extends StatefulWidget {
  const BebidasPage({
    super.key,
    this.initialComercioId,
    this.initialComercioNombre,
  });

  // (1) soporte para llegar pre-seleccionado desde ComercioDetallePage
  final String? initialComercioId;
  final String? initialComercioNombre;

  @override
  State<BebidasPage> createState() => _BebidasPageState();
}

class _BebidasPageState extends State<BebidasPage> {
  // --- Comercio seleccionado ---
  String? _comercioId;
  String? _comercioNombre;

  // --- Imagen (ImagePicker) ---
  final _picker = ImagePicker();
  XFile? _imagenSeleccionada;

  @override
  void initState() {
    super.initState();
    // Si venimos desde ComercioDetallePage, arrancamos ya posicionados
    _comercioId = widget.initialComercioId;
    _comercioNombre = widget.initialComercioNombre;
  }

  // Colección de bebidas del comercio seleccionado
  CollectionReference<Map<String, dynamic>>? get _bebidasCol {
    if (_comercioId == null) return null;
    return FirebaseFirestore.instance
        .collection('comercios')
        .doc(_comercioId)
        .collection('bebidas');
  }

  // ----------------------------------------
  // Helpers de imagen
  // ----------------------------------------

  // Elegir imagen desde galería (con compresión)
  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // reduce peso
    );
    if (x != null) {
      setState(() => _imagenSeleccionada = x);
    }
  }

  // Subir imagen a Storage y devolver URL + path interno
  // Guardamos: comercios/{comercioId}/bebidas/{bebidaId}.jpg
  Future<({String url, String path})?> _uploadImagenYObtenerUrl(String bebidaId) async {
    if (_imagenSeleccionada == null || _comercioId == null) return null;

    final file = File(_imagenSeleccionada!.path);
    final path = 'comercios/$_comercioId/bebidas/$bebidaId.jpg';
    final ref = FirebaseStorage.instance.ref().child(path);

    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    return (url: url, path: path);
  }

  // Borrar una imagen de Storage por su path
  Future<void> _deleteImageByPath(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref().child(path).delete();
    } catch (_) {
      // Si no existe, lo ignoramos en dev
    }
  }

  // ----------------------------------------
  // UI
  // ----------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_comercioNombre ?? 'Elegí un comercio'),
        actions: [
          IconButton(
            tooltip: 'Cambiar comercio',
            icon: const Icon(Icons.store_mall_directory),
            onPressed: _elegirComercio,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _bebidasCol == null
          ? null
          : FloatingActionButton(
              onPressed: () => _showEditDialog(context, _bebidasCol!, null, null),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildBody() {
    if (_bebidasCol == null) {
      return const Center(child: Text('Seleccioná un comercio para ver sus bebidas'));
    }

    // Escucha en tiempo real los cambios
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _bebidasCol!.orderBy('nombre').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No hay bebidas cargadas.'));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data();
            final nombre = (data['nombre'] ?? '') as String;
            final precio = data['precio'] ?? 0;
            final disponible = (data['disponible'] ?? true) as bool;
            final imagenUrl = data['imagenUrl'] as String?;

            return Dismissible(
              key: ValueKey(doc.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) => _confirmDelete(context, nombre),
              onDismissed: (_) async {
                // borrar imagen del Storage si existía
                await _deleteImageByPath(data['imagenPath'] as String?);
                await _bebidasCol!.doc(doc.id).delete();
              },
              child: ListTile(
                leading: imagenUrl == null
                    ? const CircleAvatar(child: Icon(Icons.local_drink))
                    : CircleAvatar(backgroundImage: NetworkImage(imagenUrl)),
                title: Text(nombre.isEmpty ? '—' : nombre),
                subtitle: Text('Precio: \$ $precio'),
                trailing: Icon(
                  disponible ? Icons.check_circle : Icons.cancel,
                  color: disponible ? Colors.green : Colors.red,
                ),
                onTap: () => _showEditDialog(context, _bebidasCol!, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  // ----------------------------------------
  // Selector de comercio
  // ----------------------------------------

  Future<void> _elegirComercio() async {
    final col = FirebaseFirestore.instance.collection('comercios');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              children: [
                const ListTile(title: Text('Seleccionar comercio')),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: col.orderBy('nombre').snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(child: Text('No hay comercios. Creá uno.'));
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final d = docs[i];
                          final data = d.data();
                          final nombre = (data['nombre'] ?? '') as String;
                          return ListTile(
                            leading: const Icon(Icons.storefront),
                            title: Text(nombre),
                            onTap: () {
                              setState(() {
                                _comercioId = d.id;
                                _comercioNombre = nombre;
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_business),
                    label: const Text('Nuevo comercio'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _crearComercioDialog();
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

  Future<void> _crearComercioDialog() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Nuevo comercio'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Nombre del comercio'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear')),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    final nombre = controller.text.trim();
    if (nombre.isEmpty) return;

    final col = FirebaseFirestore.instance.collection('comercios');
    final docRef = await col.add({
      'nombre': nombre,
      'creado': FieldValue.serverTimestamp(),
    });

    setState(() {
      _comercioId = docRef.id;
      _comercioNombre = nombre;
    });
  }

  // ----------------------------------------
  // Alta / Edición con imagen
  // ----------------------------------------
  Future<void> _showEditDialog(
    BuildContext context,
    CollectionReference<Map<String, dynamic>> bebidasCol,
    String? bebidaId,
    Map<String, dynamic>? data,
  ) async {
    final isEdit = bebidaId != null;
    final nombreCtrl = TextEditingController(text: data?['nombre']?.toString() ?? '');
    final precioCtrl = TextEditingController(text: data?['precio']?.toString() ?? '');
    bool disponible = (data?['disponible'] ?? true) as bool;

    // para previsualizar imagen ya guardada
    final imagenUrlActual = data?['imagenUrl'] as String?;
    String? imagenUrlPreview = imagenUrlActual;

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => StatefulBuilder(
            builder: (ctx, setLocalState) => AlertDialog(
              title: Text(isEdit ? 'Editar bebida' : 'Nueva bebida'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: precioCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Precio'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Disponible'),
                        const Spacer(),
                        Switch(
                          value: disponible,
                          onChanged: (v) => setLocalState(() => disponible = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_imagenSeleccionada != null)
                      Image.file(File(_imagenSeleccionada!.path), height: 140)
                    else if ((imagenUrlPreview ?? '').isNotEmpty)
                      Image.network(imagenUrlPreview!, height: 140)
                    else
                      const SizedBox.shrink(),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await _pickImage();
                            if (_imagenSeleccionada != null) {
                              setLocalState(() {
                                imagenUrlPreview = null; // oculto la previa de red
                              });
                            }
                          },
                          icon: const Icon(Icons.image),
                          label: const Text('Elegir imagen'),
                        ),
                        const SizedBox(width: 8),
                        if (_imagenSeleccionada != null || (imagenUrlPreview ?? '').isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              setLocalState(() {
                                _imagenSeleccionada = null;
                                imagenUrlPreview = null;
                              });
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Quitar imagen'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cerrar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!ok) {
      setState(() => _imagenSeleccionada = null);
      return;
    }

    final nombre = nombreCtrl.text.trim();
    final precio = num.tryParse(precioCtrl.text.trim()) ?? 0;

    final basePayload = <String, dynamic>{
      'nombre': nombre,
      'precio': precio,
      'disponible': disponible,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (isEdit) {
        // 1) Actualizar datos básicos
        await bebidasCol.doc(bebidaId).update(basePayload);

        // 2) Si se eligió NUEVA imagen:
        if (_imagenSeleccionada != null) {
          // borrar imagen anterior si había
          await _deleteImageByPath(data?['imagenPath'] as String?);

          // subir nueva y guardar url+path
          final uploaded = await _uploadImagenYObtenerUrl(bebidaId);
          if (uploaded != null) {
            await bebidasCol.doc(bebidaId).update({
              'imagenUrl': uploaded.url,
              'imagenPath': uploaded.path,
            });
          }
        } else if ((imagenUrlPreview ?? '').isEmpty && (data?['imagenPath'] != null)) {
          // Caso: usuario presionó "Quitar imagen"
          await _deleteImageByPath(data?['imagenPath'] as String?);
          await bebidasCol.doc(bebidaId).update({
            'imagenUrl': FieldValue.delete(),
            'imagenPath': FieldValue.delete(),
          });
        }
      } else {
        // CREAR
        final docRef = await bebidasCol.add({
          ...basePayload,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (_imagenSeleccionada != null) {
          final uploaded = await _uploadImagenYObtenerUrl(docRef.id);
          if (uploaded != null) {
            await docRef.update({
              'imagenUrl': uploaded.url,
              'imagenPath': uploaded.path,
            });
          }
        }
      }
    } finally {
      setState(() => _imagenSeleccionada = null);
    }
  }

  // ----------------------------------------
  // Confirmación de borrado
  // ----------------------------------------
  Future<bool> _confirmDelete(BuildContext context, String nombre) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirmar borrado'),
            content: Text('¿Eliminar "$nombre"? Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }
}