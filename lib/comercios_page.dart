import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'comercio_detalle_page.dart';

class ComerciosPage extends StatefulWidget {
  const ComerciosPage({super.key});

  @override
  State<ComerciosPage> createState() => _ComerciosPageState();
}

class _ComerciosPageState extends State<ComerciosPage> {
  final _busquedaCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comerciosCol = FirebaseFirestore.instance.collection('comercios');

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
                          // 👉 Navegamos pasando el ID del comercio
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
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
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
    );
  }
}
