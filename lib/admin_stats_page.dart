// lib/admin_stats_page.dart
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

// 👉 Usá SIEMPRE la misma fuente de verdad para adminMode/kIsAdmin
import 'admin_state.dart';

class AdminStatsPage extends StatefulWidget {
  const AdminStatsPage({super.key});

  @override
  State<AdminStatsPage> createState() => _AdminStatsPageState();
}

class _AdminStatsPageState extends State<AdminStatsPage> {
  String _range = '7d'; // '7d' | '30d'
  bool _loading = true;

  int _appOpens = 0;
  int _interactions = 0;
  int _businessViews = 0;

  // Top comercios por vistas
  List<_TopComercio> _top = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _from {
    final now = DateTime.now().toUtc();
    return _range == '30d'
        ? now.subtract(const Duration(days: 30))
        : now.subtract(const Duration(days: 7));
  }

  Future<int> _countWhereType(String type) async {
    try {
      final q = FirebaseFirestore.instance
          .collection('analytics_events')
          .where('type', isEqualTo: type)
          .where('ts', isGreaterThanOrEqualTo: _from);

      // Aggregate COUNT (si está disponible en tu versión del SDK)
      final agg = await q.count().get();
      // `count` puede ser int? según versión -> aseguramos entero
      return (agg.count ?? 0);
    } catch (_) {
      // Fallback: descargamos y contamos client-side
      final snap = await FirebaseFirestore.instance
          .collection('analytics_events')
          .where('type', isEqualTo: type)
          .where('ts', isGreaterThanOrEqualTo: _from)
          .get();
      return snap.docs.length;
    }
  }

  Future<void> _loadTopBusinesses() async {
    // Descarga eventos de business_view en el rango y agrupa por comercioId
    final snap = await FirebaseFirestore.instance
        .collection('analytics_events')
        .where('type', isEqualTo: 'business_view')
        .where('ts', isGreaterThanOrEqualTo: _from)
        .get();

    final counter = <String, int>{};
    for (final d in snap.docs) {
      final cid = (d.data()['data']?['comercioId'] ?? '').toString();
      if (cid.isEmpty) continue;
      counter[cid] = (counter[cid] ?? 0) + 1;
    }

    // Top 5 IDs
    final sorted = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topIds = sorted.take(5).map((e) => e.key).toList();

    // Fetch nombres
    final names = <String, String>{};
    for (final id in topIds) {
      final doc =
          await FirebaseFirestore.instance.collection('comercios').doc(id).get();
      names[id] = (doc.data()?['nombre'] ?? id).toString();
    }

    _top = sorted
        .take(5)
        .map((e) => _TopComercio(
              id: e.key,
              nombre: names[e.key] ?? e.key,
              views: e.value,
            ))
        .toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait<int>([
      _countWhereType('app_open'),
      _countWhereType('interaction'),
      _countWhereType('business_view'),
    ]);
    _appOpens = results[0];
    _interactions = results[1];
    _businessViews = results[2];
    await _loadTopBusinesses();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final total =
        (_appOpens + _interactions + _businessViews).clamp(0, 1 << 31);
    final pieItems = [
      _Slice(
          label: 'Entradas',
          value: _appOpens.toDouble(),
          color: cs.primary),
      _Slice(
          label: 'Interacciones',
          value: _interactions.toDouble(),
          color: cs.tertiary),
      _Slice(
          label: 'Comercios vistos',
          value: _businessViews.toDouble(),
          color: cs.secondary),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // Selector de rango
                  Row(
                    children: [
                      const Text('Rango: '),
                      const SizedBox(width: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: '7d', label: Text('7 días')),
                          ButtonSegment(value: '30d', label: Text('30 días')),
                        ],
                        selected: {_range},
                        onSelectionChanged: (s) {
                          _range = s.first;
                          _load();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tarjetas de KPIs
                  _KpiRow(items: [
                    Kpi(title: 'Entradas a la app', value: _appOpens),
                    Kpi(title: 'Interacciones', value: _interactions),
                    Kpi(title: 'Comercios vistos', value: _businessViews),
                  ]),

                  const SizedBox(height: 16),

                  // Gráfico de torta
                  _Glass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Distribución de actividad',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 220,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 36,
                              sections: pieItems.map((e) {
                                final pct = total == 0
                                    ? 0.0
                                    : (e.value / total * 100.0);
                                return PieChartSectionData(
                                  color: e.color,
                                  value: e.value,
                                  title: '${pct.toStringAsFixed(0)}%',
                                  radius: 70,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: pieItems.map((e) {
                            final pct = total == 0
                                ? 0.0
                                : (e.value / total * 100.0);
                            return _LegendDot(
                                color: e.color,
                                text:
                                    '${e.label} • ${pct.toStringAsFixed(0)}%');
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Top comercios
                  _Glass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Top comercios vistos',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (_top.isEmpty)
                          Text('Sin datos en el período seleccionado',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant))
                        else
                          Column(
                            children: _top.map((t) {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      cs.primaryContainer,
                                  child: Text(
                                    t.views.toString(),
                                    style: TextStyle(
                                        color: cs.onPrimaryContainer,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(t.nombre),
                                subtitle: Text('Vistas: ${t.views}'),
                              );
                            }).toList(),
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

class _Glass extends StatelessWidget {
  final Widget child;
  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendDot({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}

class _Slice {
  final String label;
  final double value;
  final Color color;
  _Slice({required this.label, required this.value, required this.color});
}

class Kpi {
  final String title;
  final int value;
  Kpi({required this.title, required this.value});
}

class _KpiRow extends StatelessWidget {
  final List<Kpi> items;
  const _KpiRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final isWide = c.maxWidth > 560;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((k) {
            return SizedBox(
              width: isWide
                  ? (c.maxWidth - 12 * (items.length - 1)) /
                      items.length
                  : c.maxWidth,
              child: _Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k.title,
                        style:
                            Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Text(
                      k.value.toString(),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TopComercio {
  final String id;
  final String nombre;
  final int views;
  _TopComercio(
      {required this.id, required this.nombre, required this.views});
}