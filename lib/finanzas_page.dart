// lib/finanzas_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'comercios_page.dart' show kIsAdmin;

class FinanzasPage extends StatefulWidget {
  const FinanzasPage({super.key});

  @override
  State<FinanzasPage> createState() => _FinanzasPageState();
}

class _FinanzasPageState extends State<FinanzasPage> {
  String _tab = 'resumen'; // resumen | ingresos | gastos

  // Filtro de mes (null = todos). Guardamos primer día del mes.
  DateTime? _mesElegido;

  // ====== filtro por comercio ======
  List<_ComercioOpt> _comercios = [];
  String? _comercioFiltroId; // null => "Todos"
  bool _cargandoComercios = true;

  @override
  void initState() {
    super.initState();
    _cargarComercios();
  }

  Future<void> _cargarComercios() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('comercios')
          .orderBy('nombre')
          .get();

      final items = snap.docs
          .map((d) => _ComercioOpt(
                id: d.id,
                nombre: (d.data()['nombre'] ?? '').toString(),
              ))
          .toList();

      setState(() {
        _comercios = items;
        _cargandoComercios = false;
      });
    } catch (_) {
      setState(() => _cargandoComercios = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mesLabel = _mesElegido == null
        ? 'Todos los meses'
        : DateFormat('MMMM yyyy', 'es').format(_mesElegido!);

    return Scaffold(
      appBar: AppBar(
  title: const Text('Finanzas'),
  actions: [
    IconButton(
      tooltip: 'Exportar CSV',
      onPressed: _exportarCsv,
      icon: const Icon(Icons.file_download_outlined),
    ),
    IconButton(
      tooltip: 'Elegir mes',
      onPressed: _elegirMes,
      icon: const Icon(Icons.calendar_month_outlined),
    ),
    const SizedBox(width: 4),
  ],
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(110), // 🔹 menos alto
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        children: [
          // 🔹 Scroll horizontal para que no se corte el segmented
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'resumen',
                  icon: Icon(Icons.analytics_outlined),
                  label: Text('Resumen'),
                ),
                ButtonSegment(
                  value: 'ingresos',
                  icon: Icon(Icons.trending_up),
                  label: Text('Ingresos'),
                ),
                ButtonSegment(
                  value: 'gastos',
                  icon: Icon(Icons.trending_down),
                  label: Text('Gastos'),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) =>
                  setState(() => _tab = s.first),
              multiSelectionEnabled: false,
            ),
          ),
          const SizedBox(height: 8),
          // 🔹 Wrap para que los filtros bajen de línea si no entran
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              InputChip(
                label: Text(_mesElegido == null
                    ? 'Todos los meses'
                    : DateFormat('MMMM yyyy', 'es').format(_mesElegido!)),
                avatar: const Icon(Icons.filter_list),
                onPressed: _elegirMes,
              ),
              _cargandoComercios
                  ? const SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(minHeight: 2))
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _comercioFiltroId,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todos los comercios'),
                          ),
                          ..._comercios.map(
                            (c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text(
                                c.nombre.isEmpty ? c.id : c.nombre,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _comercioFiltroId = v);
                        },
                      ),
                    ),
            ],
          ),
        ],
      ),
    ),
  ),
),
      body: _buildBody(),

      floatingActionButton: kIsAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _nuevoMovimiento(),
              label: Text(_tab == 'ingresos'
                  ? 'Nuevo ingreso'
                  : _tab == 'gastos'
                      ? 'Nuevo gasto'
                      : 'Nuevo mov.'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  // -------------------- BODY --------------------
  Widget _buildBody() {
    switch (_tab) {
      case 'resumen':
        return _ResumenFinanzas(
          mesElegido: _mesElegido,
          comercioFiltroId: _comercioFiltroId,
        );
      case 'ingresos':
        return _MovimientosList(
          tipo: 'ingreso',
          mesElegido: _mesElegido,
          comercioFiltroId: _comercioFiltroId,
        );
      case 'gastos':
        return _MovimientosList(
          tipo: 'gasto',
          mesElegido: _mesElegido,
          comercioFiltroId: _comercioFiltroId,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // -------------------- DIALOG NUEVO MOVIMIENTO --------------------
  Future<void> _nuevoMovimiento() async {
    final isGasto = _tab == 'gastos';

    final comerciosSnap = await FirebaseFirestore.instance
        .collection('comercios')
        .orderBy('nombre')
        .limit(50)
        .get();

    final items = comerciosSnap.docs
        .map((d) => _ComercioOpt(
              id: d.id,
              nombre: (d.data()['nombre'] ?? '') as String,
            ))
        .toList();

    String? comercioIdSel =
        (_comercioFiltroId != null) ? _comercioFiltroId : (items.isNotEmpty ? items.first.id : null);

    final conceptoCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    DateTime fecha = DateTime.now();

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(isGasto ? 'Nuevo gasto' : 'Nuevo ingreso'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(.6),
                      ),
                      child: const Text(
                        'No hay comercios cargados. Creá uno para registrar finanzas.',
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: comercioIdSel,
                      decoration: const InputDecoration(
                        labelText: 'Comercio',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      items: items
                          .map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.nombre.isEmpty ? e.id : e.nombre),
                              ))
                          .toList(),
                      onChanged: (v) => comercioIdSel = v,
                    ),
                  const SizedBox(height: 8),
                  _tf(conceptoCtrl, 'Concepto', Icons.description_outlined),
                  _tf(montoCtrl, 'Monto', Icons.attach_money,
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true)),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fecha,
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime(2100, 1, 1),
                      );
                      if (picked != null) {
                        setState(() => fecha = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              fecha.hour,
                              fecha.minute,
                            ));
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy HH:mm').format(fecha)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Guardar')),
            ],
          ),
        ) ??
        false;

    if (!ok || comercioIdSel == null) return;

    final comercioNombre = items
        .firstWhere((e) => e.id == comercioIdSel,
            orElse: () => _ComercioOpt(id: comercioIdSel!, nombre: ''))
        .nombre;

    final ref = FirebaseFirestore.instance
        .collection('comercios')
        .doc(comercioIdSel)
        .collection('finanzas');

    await ref.add({
      'tipo': isGasto ? 'gasto' : 'ingreso',
      'concepto': conceptoCtrl.text.trim(),
      'monto': num.tryParse(montoCtrl.text.trim()) ?? 0,
      'fecha': Timestamp.fromDate(fecha),
      'comercioId': comercioIdSel,
      'comercioNombre': comercioNombre,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movimiento guardado')),
      );
    }
  }

  // -------------------- FILTRO DE MES --------------------
  Future<void> _elegirMes() async {
    final now = DateTime.now();
    final opciones = <DateTime?>[null];
    for (int i = 0; i < 13; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      opciones.add(d);
    }

    DateTime? sel = _mesElegido;
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Filtrar por mes'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: opciones.length,
                itemBuilder: (_, i) {
                  final v = opciones[i];
                  final label = v == null
                      ? 'Todos los meses'
                      : DateFormat('MMMM yyyy', 'es').format(v);
                  final active = (v == null && sel == null) ||
                      (v != null &&
                          sel != null &&
                          v.year == sel!.year &&
                          v.month == sel!.month);
                  return ListTile(
                    dense: true,
                    title: Text(label),
                    trailing: active ? const Icon(Icons.check) : null,
                    onTap: () {
                      sel = v;
                      Navigator.pop(context, true);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ) ??
        false;

    if (ok) {
      setState(() => _mesElegido = sel);
    }
  }

  // -------------------- EXPORTAR CSV --------------------
  Future<void> _exportarCsv() async {
    final desde = _mesElegido;
    final hasta = _mesElegido != null
        ? DateTime(_mesElegido!.year, _mesElegido!.month + 1, 1)
        : null;

    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collectionGroup('finanzas');

    if (_tab == 'ingresos') q = q.where('tipo', isEqualTo: 'ingreso');
    if (_tab == 'gastos') q = q.where('tipo', isEqualTo: 'gasto');

    if (_comercioFiltroId != null) {
      q = q.where('comercioId', isEqualTo: _comercioFiltroId);
    }

    if (desde != null) {
      q = q.where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde));
    }
    if (hasta != null) {
      q = q.where('fecha', isLessThan: Timestamp.fromDate(hasta));
    }

    q = q.orderBy('fecha', descending: false);

    final snap = await q.get();
    final rows = <List<dynamic>>[];
    rows.add(['fecha', 'tipo', 'concepto', 'monto', 'comercioId', 'comercioNombre']);
    for (final d in snap.docs) {
      final m = d.data();
      final f = (m['fecha'] as Timestamp?)?.toDate();
      rows.add([
        f == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(f),
        (m['tipo'] ?? '').toString(),
        (m['concepto'] ?? '').toString(),
        (m['monto'] ?? 0).toString(),
        (m['comercioId'] ?? '').toString(),
        (m['comercioNombre'] ?? '').toString(),
      ]);
    }
    final csv = const ListToCsvConverter().convert(rows);

    if (!mounted) return;

    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV copiado al portapapeles')),
      );
    }
  }
}

// -------------------- LISTA DE MOVIMIENTOS --------------------
class _MovimientosList extends StatelessWidget {
  final String tipo; // ingreso | gasto
  final DateTime? mesElegido;
  final String? comercioFiltroId;
  const _MovimientosList({
    required this.tipo,
    required this.mesElegido,
    required this.comercioFiltroId,
  });

  @override
  Widget build(BuildContext context) {
    final desde = mesElegido;
    final hasta = mesElegido == null
        ? null
        : DateTime(mesElegido!.year, mesElegido!.month + 1, 1);

    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collectionGroup('finanzas')
          .where('tipo', isEqualTo: tipo);

    if (comercioFiltroId != null) {
      q = q.where('comercioId', isEqualTo: comercioFiltroId);
    }

    if (desde != null) {
      q = q.where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde));
    }
    if (hasta != null) {
      q = q.where('fecha', isLessThan: Timestamp.fromDate(hasta));
    }

    q = q.orderBy('fecha', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
         return _EmptyState(
    title: 'Sin movimientos',
    subtitle: 'No hay ${tipo == 'ingreso' ? 'ingresos' : 'gastos'} para el período o comercio seleccionado.',
    ctaLabel: kIsAdmin ? 'Cargar movimiento' : null,
    onCta: kIsAdmin ? () {
      // Abrimos el diálogo de nuevo movimiento del padre vía ScaffoldMessenger
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usá el botón “Nuevo mov.” para agregar uno')),
      );
    } : null,
  );
}
        

        final total = docs.fold<num>(0, (a, e) => a + ((e.data()['monto'] ?? 0) as num));
        final signo = tipo == 'ingreso' ? '+' : '-';
        final color = tipo == 'ingreso' ? Colors.green : Colors.red;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text('Total $tipo: $signo\$${total.toStringAsFixed(2)}'),
                  backgroundColor: color.withOpacity(.12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final docSnap = docs[i];
                  final d = docSnap.data();
                  final concepto = (d['concepto'] ?? '').toString();
                  final monto = (d['monto'] ?? 0) as num;
                  final fecha = (d['fecha'] as Timestamp?)?.toDate();
                  final comercio = (d['comercioNombre'] ?? '').toString();

                  return Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(tipo == 'ingreso'
                            ? Icons.trending_up
                            : Icons.trending_down),
                      ),
                      title: Text(concepto.isEmpty
                          ? (tipo == 'ingreso' ? 'Ingreso' : 'Gasto')
                          : concepto),
                      subtitle: Text(
                        '${fecha == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(fecha)}'
                        '${comercio.isEmpty ? '' : '  •  $comercio'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${tipo == 'ingreso' ? '+ ' : '- '}\$${monto.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (kIsAdmin)
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') _editarMovimiento(context, docSnap);
                                if (v == 'del')  _borrarMovimiento(context, docSnap);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Editar')),
                                PopupMenuItem(value: 'del',  child: Text('Eliminar')),
                              ],
                            ),
                        ],
                      ),
                      onLongPress: kIsAdmin ? () => _editarMovimiento(context, docSnap) : null,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editarMovimiento(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final d = doc.data();
    final conceptoCtrl = TextEditingController(text: (d['concepto'] ?? '').toString());
    final montoCtrl = TextEditingController(text: (d['monto'] ?? 0).toString());
    DateTime fecha = (d['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Editar ${ (d['tipo'] ?? '') == 'gasto' ? 'gasto' : 'ingreso'}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tf(conceptoCtrl, 'Concepto', Icons.description_outlined),
                  _tf(montoCtrl, 'Monto', Icons.attach_money,
                      keyboard: const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fecha,
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime(2100, 1, 1),
                      );
                      if (picked != null) {
                        fecha = DateTime(picked.year, picked.month, picked.day, fecha.hour, fecha.minute);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy HH:mm').format(fecha)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await doc.reference.update({
      'concepto': conceptoCtrl.text.trim(),
      'monto': num.tryParse(montoCtrl.text.trim()) ?? 0,
      'fecha': Timestamp.fromDate(fecha),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimiento actualizado')));
  }

  Future<void> _borrarMovimiento(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eliminar movimiento'),
            content: const Text('¿Seguro que querés eliminarlo?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await doc.reference.delete();

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimiento eliminado')));
  }
}

// -------------------- RESUMEN (GRÁFICO + KPIs) --------------------
class _ResumenFinanzas extends StatelessWidget {
  final DateTime? mesElegido;
  final String? comercioFiltroId;
  const _ResumenFinanzas({
    required this.mesElegido,
    required this.comercioFiltroId,
  });

  DateTime get _desde6m {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 5, 1);
  }

  @override
  Widget build(BuildContext context) {
    final desde = mesElegido ?? _desde6m;
    final hasta = mesElegido == null
        ? null
        : DateTime(mesElegido!.year, mesElegido!.month + 1, 1);

    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collectionGroup('finanzas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde));

    if (comercioFiltroId != null) {
      q = q.where('comercioId', isEqualTo: comercioFiltroId);
    }
    if (hasta != null) {
      q = q.where('fecha', isLessThan: Timestamp.fromDate(hasta));
    }

    q = q.orderBy('fecha', descending: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        final series = _acumularPorMes(docs, desde, meses: mesElegido == null ? 6 : 1);
        if (series.isEmpty) {
        return _EmptyState(
        title: 'Sin datos',
        subtitle: 'No hay movimientos en el período seleccionado.',
  );
}

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              mesElegido == null
                  ? 'Resumen últimos 6 meses'
                  : DateFormat('MMMM yyyy', 'es').format(mesElegido!),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (g, i, rod, s) {
                        final mes = series[i].label;
                        final ingreso = series[i].ingresos;
                        final gasto = series[i].gastos;
                        final bal = ingreso - gasto;
                        return BarTooltipItem(
                          '$mes\n'
                          'Ingresos: \$${ingreso.toStringAsFixed(0)}\n'
                          'Gastos:   \$${gasto.toStringAsFixed(0)}\n'
                          'Balance:  \$${bal.toStringAsFixed(0)}',
                          const TextStyle(fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= series.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(series[i].labelShort,
                                style: Theme.of(context).textTheme.bodySmall),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(series.length, (i) {
                    final s = series[i];
                    return BarChartGroupData(
                      x: i,
                      barsSpace: 8,
                      barRods: [
                        BarChartRodData(
                          toY: s.ingresos.toDouble(),
                          width: 10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: s.gastos.toDouble(),
                          width: 10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _KpiRow(series: series),
          ],
        );
      },
    );
  }

  List<_MesSerie> _acumularPorMes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    DateTime desde, {
    required int meses,
  }) {
    final start = DateTime(desde.year, desde.month, 1);
    final arr = <_MesSerie>[];
    for (int k = 0; k < meses; k++) {
      final d = DateTime(start.year, start.month + k, 1);
      final label = DateFormat('MMMM yyyy', 'es').format(d);
      final short = DateFormat('MMM', 'es').format(d);
      arr.add(_MesSerie(label: _cap(label), labelShort: _cap(short)));
    }

    for (final doc in docs) {
      final m = doc.data();
      final ts = m['fecha'] as Timestamp?;
      if (ts == null) continue;
      final f = ts.toDate();

      final idx = (f.year - start.year) * 12 + (f.month - start.month);
      if (idx < 0 || idx >= arr.length) continue;

      final tipo = (m['tipo'] ?? '').toString();
      final monto = (m['monto'] ?? 0) as num;
      if (tipo == 'ingreso') {
        arr[idx].ingresos += monto;
      } else if (tipo == 'gasto') {
        arr[idx].gastos += monto;
      }
    }
    return arr;
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _MesSerie {
  final String label;
  final String labelShort;
  num ingresos = 0;
  num gastos = 0;
  _MesSerie({required this.label, required this.labelShort});
}

class _KpiRow extends StatelessWidget {
  final List<_MesSerie> series;
  const _KpiRow({required this.series});

  @override
  Widget build(BuildContext context) {
    final totalIng = series.fold<num>(0, (a, b) => a + b.ingresos);
    final totalGas = series.fold<num>(0, (a, b) => a + b.gastos);
    final balance = totalIng - totalGas;

    Widget kpi(String label, String value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        kpi('Ingresos', '\$${totalIng.toStringAsFixed(0)}', Icons.trending_up),
        const SizedBox(width: 8),
        kpi('Gastos', '\$${totalGas.toStringAsFixed(0)}', Icons.trending_down),
        const SizedBox(width: 8),
        kpi('Balance', '\$${balance.toStringAsFixed(0)}',
            Icons.account_balance_wallet_outlined),
      ],
    );
  }
}

// -------------------- HELPERS --------------------
class _ComercioOpt {
  final String id;
  final String nombre;
  _ComercioOpt({required this.id, required this.nombre});
}

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

/// CSV simple sin paquete externo
class ListToCsvConverter {
  const ListToCsvConverter();

  String convert(List<List<dynamic>> rows) {
    final sb = StringBuffer();
    for (final row in rows) {
      sb.writeln(row.map(_escape).join(','));
    }
    return sb.toString();
  }

  String _escape(dynamic v) {
    var s = (v ?? '').toString();
    if (s.contains('"') || s.contains(',') || s.contains('\n')) {
      s = '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.outline),
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCta,
                icon: const Icon(Icons.add),
                label: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}