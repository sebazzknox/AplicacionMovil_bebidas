import 'package:flutter/material.dart';

class ComerciosMockPage extends StatefulWidget {
  const ComerciosMockPage({super.key});

  @override
  State<ComerciosMockPage> createState() => _ComerciosMockPageState();
}

class _ComerciosMockPageState extends State<ComerciosMockPage> {
  final _busquedaCtrl = TextEditingController();
  String _query = '';

  // Mock: 4 comercios “de muestra”
  final List<Map<String, String>> _comercios = const [
    {
      'nombre': 'Kiosko La Única',
      'ciudad': 'San Martín',
      'provincia': 'Mendoza',
      'foto': 'https://images.unsplash.com/photo-1541558619105-5f8e92da8b9f?w=600'
    },
    {
      'nombre': 'Bar La Cañita',
      'ciudad': 'Rosario',
      'provincia': 'Santa Fe',
      'foto': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600'
    },
    {
      'nombre': 'Distribuidora Santa Elena',
      'ciudad': 'San Juan',
      'provincia': 'San Juan',
      'foto': 'https://images.unsplash.com/photo-1514361892635-6b07e31e75ab?w=600'
    },
    {
      'nombre': 'Despensa El 24',
      'ciudad': 'Lanús',
      'provincia': 'Buenos Aires',
      'foto': 'https://images.unsplash.com/photo-1514361892635-6b07e31e75ab?w=600'
    },
  ];

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _query.trim().toLowerCase();

    final filtrados = _comercios.where((c) {
      if (q.isEmpty) return true;
      final nombre = (c['nombre'] ?? '').toLowerCase();
      final ciudad = (c['ciudad'] ?? '').toLowerCase();
      final provincia = (c['provincia'] ?? '').toLowerCase();
      return nombre.contains(q) || ciudad.contains(q) || provincia.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Comercios (demo)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _busquedaCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Provincia, ciudad o comercio',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: filtrados.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = filtrados[i];
                final subt = [
                  if ((c['ciudad'] ?? '').isNotEmpty) c['ciudad'],
                  if ((c['provincia'] ?? '').isNotEmpty) c['provincia'],
                ].join(' • ');

                return Material(
                  color: cs.surface,
                  elevation: 0.5,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Abrir detalle: ${c['nombre']}')),
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
                              child: (c['foto'] ?? '').isEmpty
                                  ? Container(
                                      color: Colors.black12,
                                      child: const Icon(Icons.storefront, size: 32),
                                    )
                                  : Image.network(c['foto']!, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c['nombre'] ?? '',
                                    style: Theme.of(context).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                if (subt.isNotEmpty)
                                  Text(subt,
                                      style: Theme.of(context).textTheme.bodySmall),
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
            ),
          ),
        ],
      ),
    );
  }
}