// lib/bebidas_page.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'admin_state.dart'; // adminMode (ValueNotifier<bool>)
import 'ofertas_page.dart' show OfertasPage;
// ✅ Descuentos por credencial
import 'services/credential_service.dart';

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
  String _cat = 'todas';                 // 'todas' | 'cervezas'
  final bool _soloPromos = false;        // estado visual “Ofertas”
  final bool _mostrarInactivas = false;  // visible solo para admin

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
          if (_soloPromos && (m['promo'] != true)) return false;

          if (_cat != 'todas') {
            final c = (m['categoria'] ?? '').toString().toLowerCase();
            if (c != 'cervezas') return false;
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

  Future<({String url, String path})?> _uploadFoto(
    String comercioId,
    String bebidaId,
  ) async {
    if (_fotoTmp == null) return null;
    final file = File(_fotoTmp!.path);
    final path = 'bebidas/$comercioId/$bebidaId.jpg';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    return (url: url, path: path);
  }

  Future<void> _deleteFotoByPath(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref(path).delete();
    } catch (_) {}
  }

  // ---------- CRUD ----------
  Future<void> _nuevaBebida() async {
    await _abrirForm();
  }

  Future<void> _editarBebida(String id, Map<String, dynamic> data) async {
    await _abrirForm(editId: id, data: data);
  }

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
        text: (data?['volumenMl'] == null)
            ? ''
            : (data!['volumenMl']).toString());
    final precioCtrl = TextEditingController(
        text: (data?['precio'] == null) ? '' : data!['precio'].toString());
    final promoPrecioCtrl = TextEditingController(
        text: (data?['promoPrecio'] == null)
            ? ''
            : data!['promoPrecio'].toString());
    final descCtrl =
        TextEditingController(text: (data?['descripcion'] ?? '').toString());

    String categoria =
        (data?['categoria'] ?? 'cervezas').toString().toLowerCase();
    bool promo = (data?['promo'] ?? false) == true;
    bool activo = (data?['activo'] ?? true) == true;

    String? fotoUrlPreview = data?['fotoUrl'] as String?;
    _fotoTmp = null;

    final categorias = <String>['cervezas'];

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
              title: Text(
                isEdit
                    ? 'Editar bebida'
                    : 'Nueva bebida en ${widget.initialComercioNombre}',
              ),
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
                              ? Image.file(
                                  File(_fotoTmp!.path),
                                  fit: BoxFit.cover,
                                )
                              : (fotoUrlPreview != null &&
                                      fotoUrlPreview!.isNotEmpty)
                                  ? Image.network(
                                      fotoUrlPreview!,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.black12,
                                      child: const Icon(
                                        Icons.add_a_photo,
                                        size: 36,
                                      ),
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
                      initialValue: categorias.contains(categoria)
                          ? categoria
                          : 'cervezas',
                      items: categorias
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c[0].toUpperCase() + c.substring(1)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => categoria = v ?? 'cervezas',
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
                                const TextInputType.numberWithOptions(
                                    decimal: false),
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
                                const TextInputType.numberWithOptions(
                                    decimal: true),
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
                            const TextInputType.numberWithOptions(
                                decimal: true),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poné un nombre para la bebida')),
        );
      }
      return;
    }

    final payload = <String, dynamic>{
      'nombre': nombre,
      'marca': marcaCtrl.text.trim(),
      'categoria': categoria, // 'cervezas'
      'volumenMl': int.tryParse(volCtrl.text.trim()),
      'precio': double.tryParse(precioCtrl.text.trim()),
      'promo': promo,
      'promoPrecio':
          promo ? double.tryParse(promoPrecioCtrl.text.trim()) : null,
      'descripcion': descCtrl.text.trim(),
      'activo': activo,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final col = _bebidasCol(widget.initialComercioId);

    if (isEdit) {
      await col.doc(editId).update(payload);
      if (_fotoTmp != null) {
        await _deleteFotoByPath(data?['fotoPath'] as String?);
        final up = await _uploadFoto(widget.initialComercioId, editId!);
        if (up != null) {
          await col.doc(editId).update(
            {'fotoUrl': up.url, 'fotoPath': up.path},
          );
        }
      } else if ((fotoUrlPreview ?? '').isEmpty &&
          (data?['fotoPath'] != null)) {
        await _deleteFotoByPath(data?['fotoPath'] as String?);
        await col.doc(editId).update({
          'fotoUrl': FieldValue.delete(),
          'fotoPath': FieldValue.delete(),
        });
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
        SnackBar(
          content: Text(isEdit ? 'Bebida actualizada' : 'Bebida creada'),
        ),
      );
      setState(() => _fotoTmp = null);
    }
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
            actions: [
              if (admin)
                IconButton(
                  tooltip: 'Nueva bebida',
                  onPressed: _nuevaBebida,
                  icon: const Icon(Icons.add),
                ),
            ],
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
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),

              // ======== Filtros (3 pastillas) ========
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _Pill(
                      icon: Icons.filter_alt_outlined,
                      label: 'Todas',
                      selected: _cat == 'todas',
                      onTap: () => setState(() => _cat = 'todas'),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      icon: Icons.local_bar_outlined,
                      label: 'Cervezas',
                      selected: _cat == 'cervezas',
                      onTap: () => setState(() => _cat = 'cervezas'),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      icon: Icons.local_offer_outlined,
                      label: 'Ofertas',
                      selected: _soloPromos,
                      tint: Colors.pink,
                      onTap: () {
                        final comercioId = widget.initialComercioId;
                        if (comercioId.isEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OfertasPage(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OfertasPage(filterComercioId: comercioId),
                            ),
                          );
                        }
                      },
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
                      return const Center(
                        child: Text('No hay bebidas para mostrar.'),
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
                        final marca = (m['marca'] ?? '') as String? ?? '';
                        final cat = (m['categoria'] ?? '') as String? ?? '';
                        final vol = (m['volumenMl'] ?? 0) as int? ?? 0;

                        // ✅ Numéricos
                        final precioNum = (m['precio'] as num?)?.toDouble() ?? 0.0;
                        final promo = (m['promo'] ?? false) == true;
                        final promoPrecioNum =
                            (m['promoPrecio'] as num?)?.toDouble();

                        final fotoUrl = m['fotoUrl'] as String?;
                        final activo = (m['activo'] ?? true) == true;

                        return _BebidaCard(
                          fotoUrl: fotoUrl,
                          title: nombre,
                          subtitle: [
                            if (marca.isNotEmpty) marca,
                            if (vol > 0) '${vol}ml',
                            if (cat.isNotEmpty) cat,
                          ].join(' • '),
                          trailing: _PriceWithCredential(
                            comercioId: widget.initialComercioId,
                            precioBase: precioNum,
                            promoPrecio: promo ? promoPrecioNum : null,
                          ),
                          inactiveLabel: activo ? null : 'inactiva',
                          onLongPress: AdminState.isAdmin(context)
                              ? () => _editarBebida(id, m)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton:
              AdminState.isAdmin(context) ? _FabNuevo(onTap:_nuevaBebida) : null,
        );
      },
    );
  }
}

// ---------- widgets auxiliares ----------

class _Pill extends StatelessWidget {
  const _Pill({
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
                  fontWeight: FontWeight.w600,
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
  const _Thumb({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 60,
        height: 60,
        child: (url == null || url!.isEmpty)
            ? Container(
                color: cs.surfaceContainerHighest.withOpacity(.5),
                child: Icon(Icons.local_drink, color: cs.onSurfaceVariant),
              )
            : Image.network(url!, fit: BoxFit.cover),
      ),
    );
  }
}

/// ---------- Card linda para cada bebida ----------
class _BebidaCard extends StatelessWidget {
  final String? fotoUrl;
  final String title;
  final String subtitle;
  final Widget trailing;
  final String? inactiveLabel;
  final VoidCallback? onLongPress;

  const _BebidaCard({
    required this.fotoUrl,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.inactiveLabel,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      elevation: 0.8,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Thumb(url: fotoUrl),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    if (inactiveLabel != null) ...[
                      const SizedBox(height: 4),
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
                constraints: const BoxConstraints(minWidth: 120, maxWidth: 150),
                child: trailing,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===== Precio con lógica de credencial/promos (rediseñado) =====
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

        final credPrice = pct > 0
            ? CredentialService.priceWithPct(precioBase, pct)
            : null;

        // Elegimos el mejor
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
          String? extraRight, // ej. "-20%"
        }) {
          final txt = '\$ ${_money(value)}';
          final baseStyle = TextStyle(
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
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
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
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
                        fontWeight: FontWeight.w700,
                        color: color ?? cs.primary,
                      ),
                    ),
                  ),
                Text(
                  txt,
                  style: strike
                      ? baseStyle.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: (color ?? cs.onSurface).withOpacity(.55),
                        )
                      : baseStyle,
                ),
              ],
            ),
          );
        }

        final rows = <Widget>[];

        // 1) Precio normal (si hay algo mejor, va tachado)
        rows.add(row(
          label: 'Precio normal',
          value: precioBase,
          strike: best < precioBase,
        ));

        // 2) Con tu credencial (si existe)
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

        // 3) Precio promo (si existe)
        if (promoPrecio != null) {
          final wins = promoPrecio! <= best + 0.0001;
          rows.add(row(
            label: 'Precio promo',
            value: promoPrecio!,
            color: Colors.pink,
            highlight: wins,
          ));
        }

        // Badge “Mejor precio” si el ganador no es el normal
        final winnerIsNormal = best == precioBase;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ...rows,
            if (!winnerIsNormal)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}