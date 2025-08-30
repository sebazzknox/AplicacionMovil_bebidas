// lib/ui/analytics_dashboard_page.dart
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

/// Si ya tenés esta flag o algún provider de admin, usalo.
/// Esto es sólo para no romper tu proyecto:
bool kIsAdmin = true;

/// Colección donde el servicio de analytics guarda los eventos.
/// Debe coincidir con tu Analytics.I.log(...)
const _kEventsCol = 'analytics_events';

class AnalyticsDashboardPage extends StatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  State<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends State<AnalyticsDashboardPage> {
  // Rango rápido: 7/30/90 días
  int _rangeDays = 30;

  DateTime get _end => DateTime.now();
  DateTime get _start => _end.subtract(Duration(days: _rangeDays));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!kIsAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estadísticas')),
        body: const Center(child: Text('Acceso solo para administradores')),
      );
    }

    final startTs = Timestamp.fromDate(DateTime(_start.year, _start.month, _start.day));
    final q = FirebaseFirestore.instance
        .collection(_kEventsCol)
        .where('ts', isGreaterThanOrEqualTo: startTs)
        .orderBy('ts', descending: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _HeaderRangeSelector(
            rangeDays: _rangeDays,
            onChange: (d) => setState(() => _rangeDays = d),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                final data = _buildStats(docs, _start, _end);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _KpiRow(
                      kpis: [
                        _Kpi('Usuarios activos', data.distinctUsers.length),
                        _Kpi('Sesiones (app_open)', data.sessions),
                        _Kpi('Vistas de comercios', data.views),
                        _Kpi('Búsquedas', data.searches),
                        _Kpi('Clicks contacto', data.contactClicks),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Serie temporal de eventos por día
                    _CardWrap(
                      title: 'Actividad por día',
                      child: SizedBox(
                        height: 220,
                        child: _LineSeries(
                          byDay: data.eventsByDay,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Top comercios por vistas
                    _CardWrap(
                      title: 'Top comercios por vistas',
                      child: Column(
                        children: [
                          for (final e in data.topComercios.take(10))
                            _TopTile(
                              title: e.name ?? ('ID: ${e.id}'),
                              subtitle: e.id,
                              value: e.views,
                            ),
                          if (data.topComercios.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text('Sin datos en el rango seleccionado',
                                  style: TextStyle(color: cs.onSurfaceVariant)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Distribución de tipos de evento (pie)
                    _CardWrap(
                      title: 'Distribución de eventos',
                      child: SizedBox(
                        height: 220,
                        child: _EventPie(data: data.eventsByType),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ------------------ MODELOS Y AGREGACIÓN ------------------

class _Agg {
  _Agg({
    required this.distinctUsers,
    required this.sessions,
    required this.views,
    required this.searches,
    required this.contactClicks,
    required this.eventsByDay,
    required this.eventsByType,
    required this.topComercios,
  });

  final Set<String> distinctUsers;
  final int sessions;
  final int views;
  final int searches;
  final int contactClicks;
  final Map<DateTime, int> eventsByDay; // fecha -> cantidad
  final Map<String, int> eventsByType;
  final List<_TopComercio> topComercios;
}

class _TopComercio {
  _TopComercio({required this.id, this.name, required this.views});
  final String id;
  final String? name;
  final int views;
}

_Agg _buildStats(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  DateTime start,
  DateTime end,
) {
  final df = DateFormat('yyyy-MM-dd');
  final byDay = SplayTreeMap<DateTime, int>(); // ordenado por fecha
  final byType = <String, int>{};
  final users = <String>{};

  int sessions = 0;
  int views = 0;
  int searches = 0;
  int contactClicks = 0;

  final viewsByComercio = <String, int>{};
  final namesByComercio = <String, String>{};

  for (final d in docs) {
    final m = d.data();
    final ts = (m['ts'] as Timestamp?)?.toDate();
    if (ts == null) continue;

    // normalizamos a medianoche para agrupar por día
    final day = DateTime(ts.year, ts.month, ts.day);
    byDay.update(day, (v) => v + 1, ifAbsent: () => 1);

    final type = (m['type'] ?? '').toString();
    if (type.isNotEmpty) byType.update(type, (v) => v + 1, ifAbsent: () => 1);

    final uid = (m['userId'] ?? '').toString();
    if (uid.isNotEmpty) users.add(uid);

    switch (type) {
      case 'app_open':
        sessions++;
        break;
      case 'view_commerce':
        views++;
        final cid = (m['comercioId'] ?? '').toString();
        if (cid.isNotEmpty) {
          viewsByComercio.update(cid, (v) => v + 1, ifAbsent: () => 1);
          final cname = (m['props']?['comercioNombre'] ?? '').toString();
          if (cname.isNotEmpty) namesByComercio[cid] = cname;
        }
        break;
      case 'search':
        searches++;
        break;
      case 'tap_call':
      case 'tap_whatsapp':
      case 'tap_instagram':
        contactClicks++;
        break;
    }
  }

  // asegurar días faltantes en el rango con 0
  for (DateTime d = DateTime(start.year, start.month, start.day);
      !d.isAfter(end);
      d = d.add(const Duration(days: 1))) {
    byDay.putIfAbsent(d, () => 0);
  }

  final top = viewsByComercio.entries
      .map((e) => _TopComercio(
            id: e.key,
            name: namesByComercio[e.key],
            views: e.value,
          ))
      .toList()
    ..sort((a, b) => b.views.compareTo(a.views));

  return _Agg(
    distinctUsers: users,
    sessions: sessions,
    views: views,
    searches: searches,
    contactClicks: contactClicks,
    eventsByDay: byDay,
    eventsByType: byType,
    topComercios: top,
  );
}

/// ------------------ WIDGETS UI ------------------

class _HeaderRangeSelector extends StatelessWidget {
  const _HeaderRangeSelector({
    required this.rangeDays,
    required this.onChange,
  });

  final int rangeDays;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget chip(int d, String label) => ChoiceChip(
          selected: rangeDays == d,
          onSelected: (_) => onChange(d),
          label: Text(label),
          selectedColor: cs.primaryContainer.withOpacity(.6),
          labelStyle: TextStyle(
            color: rangeDays == d ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        );

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          const Text('Rango:', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Wrap(spacing: 8, children: [
            chip(7, '7 días'),
            chip(30, '30 días'),
            chip(90, '90 días'),
          ]),
        ],
      ),
    );
  }
}

class _Kpi {
  _Kpi(this.title, this.value);
  final String title;
  final int value;
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpis});
  final List<_Kpi> kpis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (_, c) {
        final isWide = c.maxWidth > 560;
        final cross = isWide ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            mainAxisExtent: 86,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: kpis.length,
          itemBuilder: (_, i) {
            final k = kpis[i];
            return Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.title,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      )),
                  const Spacer(),
                  Text('${k.value}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      )),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CardWrap extends StatelessWidget {
  const _CardWrap({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LineSeries extends StatelessWidget {
  const _LineSeries({required this.byDay, required this.color});

  final Map<DateTime, int> byDay;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    final days = byDay.keys.toList()..sort();
    for (var i = 0; i < days.length; i++) {
      spots.add(FlSpot(i.toDouble(), (byDay[days[i]] ?? 0).toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: _dayTitles(days)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: _niceInterval(byDay.values),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            barWidth: 3,
            color: color,
            spots: spots,
            dotData: const FlDotData(show: false),
          ),
        ],
        borderData: FlBorderData(show: false),
        minY: 0,
      ),
    );
  }

  double _niceInterval(Iterable<int> vals) {
    final max = (vals.isEmpty ? 1 : vals.reduce((a, b) => a > b ? a : b)).toDouble();
    if (max <= 5) return 1;
    if (max <= 20) return 5;
    if (max <= 50) return 10;
    return 20;
  }

  SideTitles _dayTitles(List<DateTime> days) {
    final fmt = DateFormat('MM/dd');
    return SideTitles(
      showTitles: true,
      interval: (days.length / 6).clamp(1, 999).toDouble(),
      getTitlesWidget: (v, meta) {
        final i = v.round();
        if (i < 0 || i >= days.length) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(fmt.format(days[i]),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        );
      },
      reservedSize: 42,
    );
  }
}

class _EventPie extends StatelessWidget {
  const _EventPie({required this.data});
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Sin datos'));
    }
    final total = data.values.fold<int>(0, (a, b) => a + b);
    final sections = <PieChartSectionData>[];
    final keys = data.keys.toList()..sort();
    for (var i = 0; i < keys.length; i++) {
      final k = keys[i];
      final v = data[k]!;
      sections.add(
        PieChartSectionData(
          value: v.toDouble(),
          title: '${((v / total) * 100).toStringAsFixed(0)}%',
          radius: 54,
          titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      );
    }

    return PieChart(
      PieChartData(
        centerSpaceRadius: 36,
        sectionsSpace: 1.5,
        sections: sections,
        // leyenda simple
        // (si querés algo más pro, armamos una leyenda debajo con colores)
      ),
    );
  }
}

class _TopTile extends StatelessWidget {
  const _TopTile({required this.title, required this.subtitle, required this.value});
  final String title;
  final String subtitle;
  final int value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withOpacity(.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('$value', style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w800)),
      ),
    );
  }
}