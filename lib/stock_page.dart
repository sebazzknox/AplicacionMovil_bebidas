// lib/stock_page.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'comercios_page.dart' show kIsAdmin;

class StockPage extends StatefulWidget {
  final String comercioId;
  final String comercioNombre;
  const StockPage({
    super.key,
    required this.comercioId,
    required this.comercioNombre,
  });

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> with TickerProviderStateMixin {
  late final TabController _tab;

  CollectionReference<Map<String, dynamic>> get stockCol =>
      FirebaseFirestore.instance
          .collection('comercios')
          .doc(widget.comercioId)
          .collection('stock');

  CollectionReference<Map<String, dynamic>> get solCol =>
      FirebaseFirestore.instance
          .collection('comercios')
          .doc(widget.comercioId)
          .collection('stock_solicitudes');

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: kIsAdmin ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Stock · ${widget.comercioNombre}'),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            const Tab(text: 'Inventario'),
            if (kIsAdmin)
              Tab(
                child: _SolicitudesTabLabel(solCol: solCol),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _InventarioTab(stockCol: stockCol, solCol: solCol),
          if (kIsAdmin) _SolicitudesTab(stockCol: stockCol, solCol: solCol),
        ],
      ),
      floatingActionButton: _fab(context, cs),
    );
  }

  Widget? _fab(BuildContext context, ColorScheme cs) {
    return FloatingActionButton.extended(
      onPressed: () {
        if (kIsAdmin) {
          _abrirEditorItem(context);
        } else {
          _abrirSolicitudAlta(context);
        }
      },
      icon: Icon(kIsAdmin ? Icons.add_box_outlined : Icons.send_outlined),
      label: Text(kIsAdmin ? 'Nuevo ítem' : 'Solicitar alta'),
    );
  }

  Future<void> _abrirEditorItem(BuildContext context,
      {DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final isEdit = doc != null;
    final data = doc?.data();
    final nombreCtrl =
        TextEditingController(text: (data?['nombre'] ?? '').toString());
    final unidadCtrl =
        TextEditingController(text: (data?['unidad'] ?? 'u').toString());
    final precioCtrl =
        TextEditingController(text: (data?['precio'] ?? '').toString());
    final cantCtrl =
        TextEditingController(text: (data?['cantidad'] ?? '').toString());
    final minCtrl =
        TextEditingController(text: (data?['minimo'] ?? '').toString());

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(isEdit ? 'Editar ítem' : 'Nuevo ítem'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tf(nombreCtrl, 'Nombre', Icons.inventory_2_outlined),
                  _tf(unidadCtrl, 'Unidad (u, pack, l)', Icons.straighten),
                  _tf(
                    precioCtrl,
                    'Precio',
                    Icons.attach_money,
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  _tf(cantCtrl, 'Cantidad', Icons.tag, keyboard: TextInputType.number),
                  _tf(minCtrl, 'Mínimo', Icons.warning_amber_outlined,
                      keyboard: TextInputType.number),
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

    final nombre = nombreCtrl.text.trim();
    final unidad = unidadCtrl.text.trim().isEmpty ? 'u' : unidadCtrl.text.trim();
    final precio = num.tryParse(precioCtrl.text.trim()) ?? 0;
    final cantidad = num.tryParse(cantCtrl.text.trim()) ?? 0;
    final minimo = num.tryParse(minCtrl.text.trim()) ?? 0;

    final payload = {
      'nombre': nombre,
      'unidad': unidad,
      'precio': precio,
      'cantidad': cantidad,
      'minimo': minimo,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isEdit) {
      await doc!.reference.update(payload);
    } else {
      await stockCol.add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _abrirSolicitudAlta(BuildContext context) async {
    // No-admin pide crear un ítem
    final nombreCtrl = TextEditingController();
    final unidadCtrl = TextEditingController(text: 'u');
    final precioCtrl = TextEditingController();
    final cantCtrl = TextEditingController();
    final minCtrl = TextEditingController();

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Solicitar alta de ítem'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tf(nombreCtrl, 'Nombre', Icons.inventory_2_outlined),
                  _tf(unidadCtrl, 'Unidad (u, pack, l)', Icons.straighten),
                  _tf(
                    precioCtrl,
                    'Precio',
                    Icons.attach_money,
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  _tf(cantCtrl, 'Cantidad', Icons.tag, keyboard: TextInputType.number),
                  _tf(minCtrl, 'Mínimo', Icons.warning_amber_outlined,
                      keyboard: TextInputType.number),
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
                child: const Text('Enviar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await solCol.add({
      'tipo': 'alta',
      'estado': 'pendiente',
      'nombre': nombreCtrl.text.trim(),
      'unidad': unidadCtrl.text.trim(),
      'precio': num.tryParse(precioCtrl.text.trim()) ?? 0,
      'cantidad': num.tryParse(cantCtrl.text.trim()) ?? 0,
      'minimo': num.tryParse(minCtrl.text.trim()) ?? 0,
      'creadoAt': FieldValue.serverTimestamp(),
    });

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Solicitud enviada')));
  }
}

class _InventarioTab extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> stockCol;
  final CollectionReference<Map<String, dynamic>> solCol;
  const _InventarioTab({required this.stockCol, required this.solCol});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stockCol.orderBy('nombre').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No hay stock cargado.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data();
            final nombre = (data['nombre'] ?? '') as String;
            final unidad = (data['unidad'] ?? 'u') as String;
            final precio = (data['precio'] ?? 0) as num;
            final cantidad = (data['cantidad'] ?? 0) as num;
            final minimo = (data['minimo'] ?? 0) as num;
            final low = cantidad <= minimo && minimo > 0;

            return Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                title: Text(
                  nombre,
                  style: low
                      ? Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.red)
                      : null,
                ),
                subtitle: Text(
                  'Stock: $cantidad $unidad  •  Min: $minimo  •  \$${precio.toStringAsFixed(2)}',
                ),
                leading: low
                    ? const Icon(Icons.warning_amber_outlined, color: Colors.red)
                    : const Icon(Icons.inventory_2_outlined),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    if (kIsAdmin)
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _mostrarEditorInline(context, d),
                      ),
                    if (kIsAdmin)
                      IconButton(
                        tooltip: 'Borrar',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await _confirm(context, '¿Eliminar "$nombre"?');
                          if (ok) await d.reference.delete();
                        },
                      ),
                    if (!kIsAdmin)
                      IconButton(
                        tooltip: 'Solicitar ajuste',
                        icon: const Icon(Icons.send_outlined),
                        onPressed: () => _enviarSolicitudAjuste(context, d),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _mostrarEditorInline(
      BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data()!;
    final nombreCtrl = TextEditingController(text: (data['nombre'] ?? '').toString());
    final unidadCtrl = TextEditingController(text: (data['unidad'] ?? 'u').toString());
    final precioCtrl = TextEditingController(text: (data['precio'] ?? '').toString());
    final cantCtrl   = TextEditingController(text: (data['cantidad'] ?? '').toString());
    final minCtrl    = TextEditingController(text: (data['minimo'] ?? '').toString());

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Editar ítem'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tf(nombreCtrl, 'Nombre', Icons.inventory_2_outlined),
                  _tf(unidadCtrl, 'Unidad', Icons.straighten),
                  _tf(precioCtrl, 'Precio', Icons.attach_money,
                      keyboard: const TextInputType.numberWithOptions(decimal: true)),
                  _tf(cantCtrl, 'Cantidad', Icons.tag, keyboard: TextInputType.number),
                  _tf(minCtrl, 'Mínimo', Icons.warning_amber_outlined,
                      keyboard: TextInputType.number),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
            ],
          ),
        ) ?? false;

    if (!ok) return;

    await doc.reference.update({
      'nombre': nombreCtrl.text.trim(),
      'unidad': unidadCtrl.text.trim(),
      'precio': num.tryParse(precioCtrl.text.trim()) ?? 0,
      'cantidad': num.tryParse(cantCtrl.text.trim()) ?? 0,
      'minimo': num.tryParse(minCtrl.text.trim()) ?? 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _enviarSolicitudAjuste(
      BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data()!;
    final nombre = (data['nombre'] ?? '') as String;

    final deltaCtrl = TextEditingController();
    final precioCtrl = TextEditingController(
        text: data['precio'] == null ? '' : data['precio'].toString());

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Solicitud de ajuste · $nombre'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tf(deltaCtrl, 'Δ Cantidad (+/-)', Icons.exposure_plus_1,
                    keyboard: TextInputType.number),
                _tf(precioCtrl, 'Nuevo precio (opcional)', Icons.attach_money,
                    keyboard: const TextInputType.numberWithOptions(decimal: true)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enviar')),
            ],
          ),
        ) ?? false;

    if (!ok) return;

    await solCol.add({
      'tipo': 'ajuste',
      'estado': 'pendiente',
      'itemId': doc.id,
      'deltaCantidad': num.tryParse(deltaCtrl.text.trim()) ?? 0,
      'nuevoPrecio': num.tryParse(precioCtrl.text.trim()),
      'creadoAt': FieldValue.serverTimestamp(),
    });

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud enviada')),
    );
  }

  Future<bool> _confirm(BuildContext context, String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
            ],
          ),
        ) ??
        false;
  }
}

class _SolicitudesTab extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> stockCol;
  final CollectionReference<Map<String, dynamic>> solCol;
  const _SolicitudesTab({required this.stockCol, required this.solCol});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: solCol.orderBy('creadoAt', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Sin solicitudes por ahora.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data();
            final tipo = (data['tipo'] ?? '') as String;
            final estado = (data['estado'] ?? 'pendiente') as String;

            final tile = ListTile(
              leading: CircleAvatar(
                child: Icon(
                  tipo == 'alta' ? Icons.add_box_outlined : Icons.build_circle_outlined,
                ),
              ),
              title: Text(tipo == 'alta'
                  ? 'Alta: ${(data['nombre'] ?? '') as String}'
                  : 'Ajuste: ${(data['itemId'] ?? '') as String}'),
              subtitle: Text(_subtituloSolicitud(data)),
              trailing: _chipEstado(context, estado),
              onTap: kIsAdmin ? () => _aprobarORechazar(context, d) : null,
            );

            return Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              child: tile,
            );
          },
        );
      },
    );
  }

  String _subtituloSolicitud(Map<String, dynamic> data) {
    if ((data['tipo'] ?? '') == 'alta') {
      final u = (data['unidad'] ?? 'u') as String;
      final c = (data['cantidad'] ?? 0) as num;
      final p = (data['precio'] ?? 0) as num;
      final m = (data['minimo'] ?? 0) as num;
      return 'unidad: $u  •  cant: $c  •  min: $m  •  \$${p.toStringAsFixed(2)}';
    } else {
      final d = (data['deltaCantidad'] ?? 0) as num;
      final np = data['nuevoPrecio'];
      return 'Δ cant: ${d >= 0 ? '+' : ''}$d'
          '${np == null ? '' : '  •  nuevo precio: \$${(np as num).toStringAsFixed(2)}'}';
    }
  }

  Widget _chipEstado(BuildContext context, String estado) {
    final cs = Theme.of(context).colorScheme;
    Color bg;
    switch (estado) {
      case 'aprobada':
        bg = Colors.green.withOpacity(.15);
        break;
      case 'rechazada':
        bg = Colors.red.withOpacity(.15);
        break;
      default:
        bg = cs.surfaceContainerHighest.withOpacity(.6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(estado),
    );
  }

  Future<void> _aprobarORechazar(
      BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data()!;
    final isAlta = (data['tipo'] == 'alta');
    final acciones = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(isAlta ? 'Alta de ítem' : 'Ajuste de stock')),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Aprobar'),
              onTap: () => Navigator.pop(context, 'aprobar'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('Rechazar'),
              onTap: () => Navigator.pop(context, 'rechazar'),
            ),
          ],
        ),
      ),
    );

    if (acciones == null) return;

    if (acciones == 'rechazar') {
      await doc.reference.update({'estado': 'rechazada'});
      return;
    }

    // Aprobar:
    if (isAlta) {
      await stockCol.add({
        'nombre': data['nombre'],
        'unidad': data['unidad'] ?? 'u',
        'precio': data['precio'] ?? 0,
        'cantidad': data['cantidad'] ?? 0,
        'minimo': data['minimo'] ?? 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await doc.reference.update({'estado': 'aprobada'});
    } else {
      final itemId = data['itemId'] as String?;
      if (itemId == null) {
        await doc.reference.update({'estado': 'rechazada'});
        return;
      }
      final itemRef = stockCol.doc(itemId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(itemRef);
        final cur = snap.data() as Map<String, dynamic>?;
        if (cur == null) return;
        final cantidad = (cur['cantidad'] ?? 0) as num;
        final nuevoPrecio = data['nuevoPrecio'] as num?;
        final nuevaCant = cantidad + (data['deltaCantidad'] as num? ?? 0);
        tx.update(itemRef, {
          'cantidad': max(0, nuevaCant),
          if (nuevoPrecio != null) 'precio': nuevoPrecio,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      await doc.reference.update({'estado': 'aprobada'});
    }
  }
}

class _SolicitudesTabLabel extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> solCol;
  const _SolicitudesTabLabel({required this.solCol});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: solCol.where('estado', isEqualTo: 'pendiente').snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Solicitudes'),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$count', style: TextStyle(color: cs.onPrimaryContainer)),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ------ helpers UI
Widget _tf(TextEditingController c, String label, IconData icon,
    {TextInputType? keyboard}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: c,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
