// lib/bebidas_page.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'admin_state.dart'; // adminMode (ValueNotifier<bool>)
import 'bebida_detalle_page.dart';
import 'services/credential_service.dart';

const String _CLOUDINARY_CLOUD_NAME = 'dlk7onebj';
const String _CLOUDINARY_UPLOAD_PRESET = 'mi_default';

/// ── Helper global: adapta URLs de Cloudinary a cuadrado (1:1) del tamaño físico.
/// Si no es Cloudinary o no tiene `/image/upload/`, devuelve la URL tal cual.
String _cloudinarySquare(String url, {required int sizePx}) {
  const marker = '/image/upload/';
  if (!url.contains('res.cloudinary.com') || !url.contains(marker)) return url;
  final tr = 'f_auto,q_auto,c_fill,ar_1:1,w_$sizePx,h_$sizePx';
  return url.replaceFirst(marker, '$marker$tr/');
}

class BebidasPage extends StatefulWidget {
  const BebidasPage({
    super.key,
    required this.initialComercioId,
    required this.initialComercioNombre,
  });

  final String initialComercioId;
  final String initialComercioNombre;

  @override
  State<BebidasPage> createState() => _BebidasPageState();
}

class _BebidasPageState extends State<BebidasPage> {
  final _busquedaCtrl = TextEditingController();
  String _q = '';

  /// 'todas' | 'alcoholicas' | 'pallet' | 'energizantes' | 'gaseosas'
  String _filtro = 'todas';

  final bool _mostrarInactivas = false; // visible solo para admin

  final _picker = ImagePicker();
  XFile? _fotoTmp;

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  // ---------- Helpers de datos ----------
  CollectionReference<Map<String, dynamic>> _bebidasCol(String comercioId) {
    return FirebaseFirestore.instance
        .collection('comercios')
        .doc(comercioId)
        .collection('bebidas');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamBebidas(
    String comercioId,
  ) {
    return _bebidasCol(comercioId).orderBy('nombre').snapshots();
  }

  String _prettyCat(String c) {
    switch (c.toLowerCase()) {
      case 'alcoholicas':
        return 'Alcohólicas';
      case 'pallet':
        return 'Pallet';
      case 'energizantes':
        return 'Energizantes';
      case 'gaseosas':
        return 'Gaseosas';
      default:
        return c.isEmpty ? '' : (c[0].toUpperCase() + c.substring(1));
    }
  }

  bool _isAlcoholica(Map<String, dynamic> m) {
    final cat = (m['categoria'] ?? '').toString().toLowerCase();
    if (cat == 'alcoholicas' || cat == 'cervezas') return true;

    final nom = (m['nombre'] ?? '').toString().toLowerCase();
    final marca = (m['marca'] ?? '').toString().toLowerCase();
    final s = '$cat $nom $marca';

    const kw = [
      'cerveza',
      'vino',
      'vinos',
      'fernet',
      'whisky',
      'licor',
      'vodka',
      'gin',
      'ron',
      'aperitivo',
      'sidra',
      'champagne',
      'espumante',
      'tequila',
      'aperol'
    ];
    return kw.any((k) => s.contains(k));
  }

  bool _isEnergizante(Map<String, dynamic> m) {
    final cat = (m['categoria'] ?? '').toString().toLowerCase();
    if (cat == 'energizantes') return true;

    final nom = (m['nombre'] ?? '').toString().toLowerCase();
    final marca = (m['marca'] ?? '').toString().toLowerCase();
    final s = '$cat $nom $marca';

    const kw = [
      'energizante',
      'energy',
      'energy drink',
      'speed',
      'red bull',
      'monster',
      'rockstar',
      'b12',
      'guaraná',
      'guarana'
    ];
    return kw.any((k) => s.contains(k));
  }

  bool _isGaseosa(Map<String, dynamic> m) {
    final cat = (m['categoria'] ?? '').toString().toLowerCase();
    if (cat == 'gaseosas') return true;

    final nom = (m['nombre'] ?? '').toString().toLowerCase();
    final marca = (m['marca'] ?? '').toString().toLowerCase();
    final s = '$cat $nom $marca';

    const kw = [
      'gaseosa',
      'soda',
      'cola',
      'coca',
      'coca-cola',
      'coca cola',
      'sprite',
      'fanta',
      'pepsi',
      '7up',
      'manaos'
    ];
    return kw.any((k) => s.contains(k));
  }

  bool _isPallet(Map<String, dynamic> m) {
    final cat = (m['categoria'] ?? '').toString().toLowerCase();

    final palletFlag = (m['pallet'] == true) || (m['porPallet'] == true);
    final cantidad = (m['cantidad'] is num)
        ? (m['cantidad'] as num).toInt()
        : (m['packCantidad'] is num)
            ? (m['packCantidad'] as num).toInt()
            : 0;
    if (palletFlag || cantidad >= 6) return true;

    final nom = (m['nombre'] ?? '').toString().toLowerCase();
    final marca = (m['marca'] ?? '').toString().toLowerCase();
    final s = '$nom $marca';
    const kw = ['pack', 'caja', 'x6', 'x12', 'x24', 'pallet'];

    return cat == 'pallet' || kw.any((k) => s.contains(k));
  }

  List<Map<String, dynamic>> _aplicarFiltros(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final q = _q.trim().toLowerCase();

    return docs
        .map((d) => {'id': d.id, ...d.data()})
        .where((m) {
          if (!_mostrarInactivas) {
            final activo = (m['activo'] ?? true) == true;
            if (!activo) return false;
          }

          switch (_filtro) {
            case 'alcoholicas':
              if (!_isAlcoholica(m)) return false;
              break;
            case 'pallet':
              if (!_isPallet(m)) return false;
              break;
            case 'energizantes':
              if (!_isEnergizante(m)) return false;
              break;
            case 'gaseosas':
              if (!_isGaseosa(m)) return false;
              break;
            case 'todas':
            default:
              break;
          }

          if (q.isEmpty) return true;
          final nom = (m['nombre'] ?? '').toString().toLowerCase();
          final marca = (m['marca'] ?? '').toString().toLowerCase();
          return nom.contains(q) || marca.contains(q);
        })
        .toList();
  }

  // ---------- Storage ----------
  Future<void> _pickFoto(StateSetter setLocal) async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (x != null) setLocal(() => _fotoTmp = x);
  }

  /// Subida con Cloudinary (unsigned). Si no está configurado, fallback a Firebase Storage.
  Future<({String url, String path})?> _uploadFoto(
    String comercioId,
    String bebidaId,
  ) async {
    if (_fotoTmp == null) return null;
    try {
      final hasCloudinary =
          _CLOUDINARY_CLOUD_NAME.isNotEmpty && _CLOUDINARY_UPLOAD_PRESET.isNotEmpty;

      if (hasCloudinary) {
        final uri = Uri.parse(
            'https://api.cloudinary.com/v1_1/$_CLOUDINARY_CLOUD_NAME/image/upload');

        final req = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = _CLOUDINARY_UPLOAD_PRESET
          ..files.add(await http.MultipartFile.fromPath('file', _fotoTmp!.path));

        final res = await req.send();
        final body = await res.stream.bytesToString();

        if (res.statusCode != 200 && res.statusCode != 201) {
          throw Exception('Cloudinary ${res.statusCode}: $body');
        }

        final json = jsonDecode(body) as Map<String, dynamic>;
        final url = (json['secure_url'] ?? json['url'])?.toString();
        final publicId = json['public_id']?.toString();
        if (url == null || url.isEmpty) {
          throw Exception('Respuesta sin URL de imagen');
        }
        // path simbólico para distinguir que viene de Cloudinary
        return (url: url, path: publicId != null ? 'cloudinary:$publicId' : '');
      }

      // Fallback: Firebase Storage
      final file = File(_fotoTmp!.path);
      final path = 'bebidas/$comercioId/$bebidaId.jpg';
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      return (url: url, path: path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo subir la foto: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _deleteFotoByPath(String? path) async {
    if (path == null || path.isEmpty) return;
    final p = path.trim();

    // URLs/Cloudinary no se borran en Firebase
    if (p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.startsWith('cloudinary:') ||
        p.contains('res.cloudinary.com')) {
      return;
    }
    try {
      await FirebaseStorage.instance.ref(p).delete();
    } catch (_) {}
  }

  // ---------- CRUD ----------
  Future<void> _nuevaBebida() async => _abrirForm();

  Future<void> _editarBebida(String id, Map<String, dynamic> data) async =>
      _abrirForm(editId: id, data: data);

  Future<void> _eliminarBebida(String id, Map<String, dynamic> data) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eliminar bebida'),
            content: Text(
              '¿Eliminar "${data['nombre'] ?? 'bebida'}"? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await _deleteFotoByPath(data['fotoPath'] as String?);
    await _bebidasCol(widget.initialComercioId).doc(id).delete();
  }

  Future<void> _abrirForm({String? editId, Map<String, dynamic>? data}) async {
    final isEdit = editId != null;
    final nombreCtrl =
        TextEditingController(text: (data?['nombre'] ?? '').toString());
    final marcaCtrl =
        TextEditingController(text: (data?['marca'] ?? '').toString());
    final volCtrl = TextEditingController(
        text: (data?['volumenMl'] == null) ? '' : (data!['volumenMl']).toString());
    final precioCtrl = TextEditingController(
        text: (data?['precio'] == null) ? '' : data!['precio'].toString());
    final promoPrecioCtrl = TextEditingController(
        text: (data?['promoPrecio'] == null) ? '' : data!['promoPrecio'].toString());
    final descCtrl =
        TextEditingController(text: (data?['descripcion'] ?? '').toString());

    String categoria = (data?['categoria'] ?? 'otras').toString().toLowerCase();
    if (categoria == 'cervezas') categoria = 'alcoholicas'; // compat vieja

    bool promo = (data?['promo'] ?? false) == true;
    bool activo = (data?['activo'] ?? true) == true;

    String? fotoUrlPreview = data?['fotoUrl'] as String?;
    _fotoTmp = null;

    final categorias = <String>['alcoholicas', 'pallet', 'energizantes', 'gaseosas', 'otras'];

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
              title: Text(isEdit
                  ? 'Editar bebida'
                  : 'Nueva bebida en ${widget.initialComercioNombre}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    if (_fotoTmp != null || ((fotoUrlPreview ?? '').isNotEmpty))
                      TextButton.icon(
                        onPressed: () => setLocal(() {
                          _fotoTmp = null;
                          fotoUrlPreview = null; // marcado como removida
                        }),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Quitar foto'),
                      ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        prefixIcon: Icon(Icons.local_drink),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: marcaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Marca',
                        prefixIcon: Icon(Icons.style_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: categorias.contains(categoria) ? categoria : 'otras',
                      items: categorias
                          .map((c) => DropdownMenuItem(value: c, child: Text(_prettyCat(c))))
                          .toList(),
                      onChanged: (v) => categoria = v ?? 'otras',
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: volCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: false),
                            decoration: const InputDecoration(
                              labelText: 'Volumen (ml)',
                              prefixIcon: Icon(Icons.local_bar_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: precioCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Precio',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: promo,
                      onChanged: (v) => setLocal(() => promo = v),
                      title: const Text('Tiene promo'),
                    ),
                    if (promo)
                      TextField(
                        controller: promoPrecioCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Precio promo',
                          prefixIcon: Icon(Icons.local_offer_outlined),
                        ),
                      ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),

                    CheckboxListTile(
                      value: activo,
                      onChanged: (v) => setLocal(() => activo = v ?? true),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activo'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!ok) return;

    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Poné un nombre para la bebida')));
      }
      return;
    }

    final payload = <String, dynamic>{
      'nombre': nombre,
      'marca': marcaCtrl.text.trim(),
      'categoria': categoria,
      'volumenMl': int.tryParse(volCtrl.text.trim()),
      'precio': double.tryParse(precioCtrl.text.trim()),
      'promo': promo,
      'promoPrecio': promo ? double.tryParse(promoPrecioCtrl.text.trim()) : null,
      'descripcion': descCtrl.text.trim(),
      'activo': activo,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final col = _bebidasCol(widget.initialComercioId);

    if (isEdit) {
      final docRef = col.doc(editId);
      await docRef.update(payload);

      if (_fotoTmp != null) {
        await _deleteFotoByPath(data?['fotoPath'] as String?);
        final up = await _uploadFoto(widget.initialComercioId, editId!);
        if (up != null) {
          await docRef.update({'fotoUrl': up.url, 'fotoPath': up.path});
        }
      } else {
        final removed = (fotoUrlPreview ?? '').isEmpty;
        if (removed) {
          await _deleteFotoByPath(data?['fotoPath'] as String?);
          await docRef.update({
            'fotoUrl': FieldValue.delete(),
            'fotoPath': FieldValue.delete(),
          });
        }
      }
    } else {
      final ref = await col.add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (_fotoTmp != null) {
        final up = await _uploadFoto(widget.initialComercioId, ref.id);
        if (up != null) {
          await ref.update({'fotoUrl': up.url, 'fotoPath': up.path});
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Bebida actualizada' : 'Bebida creada')),
      );
      setState(() => _fotoTmp = null);
    }
  }

  // ---------- Navegación a Detalle ----------
  void _abrirDetalle(String id, Map<String, dynamic> m) {
    final isAdmin = AdminState.isAdmin(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BebidaDetallePage(
          comercioId: widget.initialComercioId,
          bebidaId: id,
          data: m,
          onEdit: isAdmin ? () => _editarBebida(id, m) : null,
          onDelete: isAdmin ? () => _eliminarBebida(id, m) : null,
        ),
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: adminMode,
      builder: (context, isAdmin, _) {
        final admin = AdminState.isAdmin(context);
        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: Text('Bebidas · ${widget.initialComercioNombre}'),
            centerTitle: false,
          ),
          body: Column(
            children: [
              // Búsqueda
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _busquedaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o marca',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: (_q.isEmpty)
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            onPressed: () {
                              _busquedaCtrl.clear();
                              setState(() => _q = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(.6),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withOpacity(.2),
                      ),
                    ),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),

              // Filtros
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _Pill(
                      icon: Icons.filter_alt_outlined,
                      label: 'Todas',
                      selected: _filtro == 'todas',
                      onTap: () => setState(() => _filtro = 'todas'),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      icon: Icons.wine_bar,
                      label: 'Alcohólicas',
                      selected: _filtro == 'alcoholicas',
                      onTap: () => setState(() => _filtro = 'alcoholicas'),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      icon: Icons.inventory_2_outlined,
                      label: 'Pallet',
                      selected: _filtro == 'pallet',
                      onTap: () => setState(() => _filtro = 'pallet'),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      icon: Icons.bolt,
                      label: 'Energizantes',
                      selected: _filtro == 'energizantes',
                      onTap: () => setState(() => _filtro = 'energizantes'),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      icon: Icons.local_drink_outlined,
                      label: 'Gaseosas',
                      selected: _filtro == 'gaseosas',
                      onTap: () => setState(() => _filtro = 'gaseosas'),
                    ),
                    const SizedBox(width: 8),
                    if (admin)
                      _Pill(
                        icon: Icons.add_rounded,
                        label: 'Nueva',
                        selected: false,
                        onTap: _nuevaBebida,
                      ),
                  ],
                ),
              ),
              // Lista
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _streamBebidas(widget.initialComercioId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }
                    final docs = snap.data?.docs ?? [];
                    final items = _aplicarFiltros(docs);

                    if (items.isEmpty) {
                      return const _EmptyState(
                        title: 'Sin resultados',
                        subtitle:
                            'Probá con otro nombre/marca o cambiá los filtros.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final m = items[i];
                        final id = m['id'] as String;
                        final nombre = (m['nombre'] ?? '') as String;
                        final marca = (m['marca'] as String?) ?? '';
                        final cat = (m['categoria'] as String?) ?? '';
                        final vol = (m['volumenMl'] as int?) ?? 0;

                        final precioNum =
                            (m['precio'] as num?)?.toDouble() ?? 0.0;
                        final promo = (m['promo'] ?? false) == true;
                        final promoPrecioNum =
                            (m['promoPrecio'] as num?)?.toDouble();

                        final fotoUrl = m['fotoUrl'] as String?;
                        final activo = (m['activo'] ?? true) == true;

                        return _BebidaCard(
                          heroTag: 'bebida_$id',
                          fotoUrl: fotoUrl,
                          isPromo: promo,
                          title: nombre,
                          subtitle: [
                            if (marca.isNotEmpty) marca,
                            if (vol > 0) '${vol}ml',
                            if (cat.isNotEmpty) _prettyCat(cat),
                          ].join(' • '),
                          trailing: _PriceWithCredential(
                            comercioId: widget.initialComercioId,
                            precioBase: precioNum,
                            promoPrecio: promo ? promoPrecioNum : null,
                          ),
                          inactiveLabel: activo ? null : 'inactiva',
                          onTap: () => _abrirDetalle(id, m),
                          onLongPress:
                              AdminState.isAdmin(context) ? () => _editarBebida(id, m) : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton:
              AdminState.isAdmin(context) ? _FabNuevo(onTap: _nuevaBebida) : null,
        );
      },
    );
  }
}

// ---------- widgets auxiliares ----------

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected
        ? (tint ?? cs.primary).withOpacity(.18)
        : cs.surfaceContainerHighest.withOpacity(.45);
    final fg = selected ? (tint ?? cs.primary) : cs.onSurfaceVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FabNuevo extends StatelessWidget {
  const _FabNuevo({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      icon: const Icon(Icons.local_drink_outlined),
      label: const Text('Nueva bebida'),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url, this.badge, this.heroTag});
  final String? url;
  final Widget? badge;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Cuadrado de 64 px
    const side = 64.0;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheW = (side * dpr).round();

    // Placeholder degradado
    final placeholder = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primaryContainer, cs.secondaryContainer],
        ),
      ),
      child: Icon(Icons.local_drink, color: cs.onPrimaryContainer),
    );

    // Imagen (Cloudinary 1:1, otros: cover centrado)
    Widget buildImage(String u) {
      final src = _cloudinarySquare(u, sizePx: cacheW);
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          src,
          width: side,
          height: side,
          fit: BoxFit.cover,           // llena el cuadro recortando al centro
          alignment: Alignment.center,
          cacheWidth: cacheW,          // ahorra memoria en lista
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => placeholder,
          loadingBuilder: (c, child, prog) {
            if (prog == null) return child;
            return Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: cs.surfaceContainerHighest.withOpacity(.5),
              ),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      );
    }

    final thumb = Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
      ),
      clipBehavior: Clip.hardEdge,
      child: (url == null || url!.isEmpty) ? placeholder : buildImage(url!),
    );

    final content = (heroTag != null) ? Hero(tag: heroTag!, child: thumb) : thumb;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        if (badge != null)
          Positioned(
            right: -4,
            top: -4,
            child: badge!,
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_drink_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de cada bebida
class _BebidaCard extends StatelessWidget {
  final String? fotoUrl;
  final bool isPromo;
  final String title;
  final String subtitle;
  final Widget trailing;
  final String? inactiveLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? heroTag;

  const _BebidaCard({
    required this.fotoUrl,
    required this.isPromo,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.inactiveLabel,
    this.onTap,
    this.onLongPress,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final promoBadge = isPromo
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.pink.withOpacity(.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.pink.withOpacity(.35)),
            ),
            child: const Text(
              'Promo',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color.fromARGB(255, 233, 121, 30),
                letterSpacing: .2,
              ),
            ),
          )
        : null;

    return Material(
      color: cs.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Thumb(url: fotoUrl, badge: promoBadge, heroTag: heroTag),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: .1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    if (inactiveLabel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        inactiveLabel!,
                        style: TextStyle(fontSize: 11, color: cs.error),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120, maxWidth: 160),
                child: trailing,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Precio con lógica de credencial/promos =====
class _PriceWithCredential extends StatelessWidget {
  final String comercioId;
  final double precioBase;
  final double? promoPrecio;

  const _PriceWithCredential({
    required this.comercioId,
    required this.precioBase,
    this.promoPrecio,
  });

  String _money(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<double>(
      stream: CredentialService.watchDiscountPctForComercio(comercioId),
      builder: (context, snap) {
        final pct = snap.data ?? 0.0;

        final credPrice =
            pct > 0 ? CredentialService.priceWithPct(precioBase, pct) : null;

        final candidates = <double>[
          precioBase,
          if (credPrice != null) credPrice,
          if (promoPrecio != null) promoPrecio!,
        ];
        final best = candidates.reduce((a, b) => a < b ? a : b);

        Widget row({
          required String label,
          required double value,
          Color? color,
          bool highlight = false,
          bool strike = false,
          String? extraRight,
        }) {
          final txt = '\$ ${_money(value)}';
          final baseStyle = TextStyle(
            fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
            color: color ?? cs.onSurface,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 8),
                if (extraRight != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      extraRight,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color ?? cs.primary,
                      ),
                    ),
                  ),
                Text(
                  txt,
                  style: strike
                      ? baseStyle.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: (color ?? cs.onSurface).withOpacity(.50),
                        )
                      : baseStyle,
                ),
              ],
            ),
          );
        }

        final rows = <Widget>[];

        rows.add(row(
          label: 'Precio normal',
          value: precioBase,
          strike: best < precioBase,
        ));

        if (credPrice != null) {
          final wins = credPrice <= best + 0.0001;
          rows.add(row(
            label: 'Con tu credencial',
            value: credPrice,
            color: Colors.green,
            highlight: wins,
            extraRight: '-${pct.toStringAsFixed(0)}%',
          ));
        }

        if (promoPrecio != null) {
          final wins = promoPrecio! <= best + 0.0001;
          rows.add(row(
            label: 'Precio promo',
            value: promoPrecio!,
            color: Colors.pink,
            highlight: wins,
          ));
        }

        final winnerIsNormal = best == precioBase;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ...rows,
              if (!winnerIsNormal)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: cs.primary),
                      const SizedBox(width: 6),
                      const Text(
                        'Mejor precio',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
