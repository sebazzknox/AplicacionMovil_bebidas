import 'package:flutter/material.dart';

class FinanzasPage extends StatefulWidget {
  const FinanzasPage({super.key});

  @override
  State<FinanzasPage> createState() => _FinanzasPageState();
}

class _FinanzasPageState extends State<FinanzasPage> {
  String _tab = 'resumen'; // resumen | ingresos | gastos

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finanzas')),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'resumen', icon: Icon(Icons.analytics_outlined), label: Text('Resumen')),
                ButtonSegment(value: 'ingresos', icon: Icon(Icons.trending_up), label: Text('Ingresos')),
                ButtonSegment(value: 'gastos', icon: Icon(Icons.trending_down), label: Text('Gastos')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
              multiSelectionEnabled: false,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_tab == 'ingresos' ? 'Nuevo ingreso' : _tab == 'gastos' ? 'Nuevo gasto' : '—')),
          );
        },
        label: Text(_tab == 'ingresos' ? 'Nuevo ingreso' : _tab == 'gastos' ? 'Nuevo gasto' : '…'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 'resumen':
        return const Center(child: Text('Gráficos y KPIs (ingresos, gastos, margen)'));
      case 'ingresos':
        return const Center(child: Text('Listado de ingresos'));
      case 'gastos':
        return const Center(child: Text('Listado de gastos'));
      default:
        return const SizedBox.shrink();
    }
  }
}