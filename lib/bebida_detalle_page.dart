// lib/bebida_detalle_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/credential_service.dart';

class BebidaDetallePage extends StatelessWidget {
  const BebidaDetallePage({
    super.key,
    required this.comercioId,
    required this.bebidaId,
    required this.data,
    this.onEdit,
    this.onDelete,
  });

  final String comercioId;
  final String bebidaId;
  final Map<String, dynamic> data;
  final VoidCallback? onEdit;     // si es admin viene seteado
  final VoidCallback? onDelete;   // si es admin viene seteado

  double _toDouble(dynamic v) =>
      (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

  int _toInt(dynamic v) =>
      (v is int) ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  String _money(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  }

  // --- Heurísticas para mostrar chips en el detalle ---
  bool _isAlcoholica(Map<String, dynamic> m) {
    final cat = (m['categoria'] ?? '').toString().toLowerCase();
    final nom = (m['nombre'] ?? '').toString().toLowerCase();
    final marca = (m['marca'] ?? '').toString().toLowerCase();
    final s = '$cat $nom $marca';

    const alcoholCats = {
      'cervezas',
      'vinos',
      'destilados',
      'aperitivos',
      'sidras',
      'espumantes',
    };
    if (alcoholCats.contains(cat)) return true;

    const kw = [
      'cerveza','vino','vinos','fernet','whisky','licor','vodka','gin','ron',
      'aperitivo','sidra','champagne','espumante','tequila','aperol'
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
      'energizante','energy','energy drink','speed','red bull','monster',
      'rockstar','vibe','b12','guaraná','guarana'
    ];
    return kw.any((k) => s.contains(k));
  }

  bool _isPallet(Map<String, dynamic> m) {
    final palletFlag = (m['pallet'] == true) || (m['porPallet'] == true);
    final cantidad =
        (m['cantidad'] is num) ? (m['cantidad'] as num).toInt() :
        (m['packCantidad'] is num) ? (m['packCantidad'] as num).toInt() : 0;
    if (palletFlag || cantidad >= 6) return true;

    final nom = (m['nombre'] ?? '').toString().toLowerCase();
    final marca = (m['marca'] ?? '').toString().toLowerCase();
    final s = '$nom $marca';
    final kw = ['pack', 'caja', 'x6', 'x12', 'x24', 'pallet'];
    return kw.any((k) => s.contains(k));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final nombre = (data['nombre'] as String?) ?? '';
    final marca = (data['marca'] as String?) ?? '';
    final categoria = (data['categoria'] as String?) ?? '';
    final vol = _toInt(data['volumenMl']);
    final precio = _toDouble(data['precio']);
    final isPromo = (data['promo'] ?? false) == true;
    final promoPrecio = isPromo ? _toDouble(data['promoPrecio']) : null;
    final descripcion = (data['descripcion'] as String?) ?? '';
    final activo = (data['activo'] ?? true) == true;
    final fotoUrl = (data['fotoUrl'] as String?) ?? '';

    final subtitle = [
      if (marca.isNotEmpty) marca,
      if (vol > 0) '${vol}ml',
      if (categoria.isNotEmpty) categoria,
    ].join(' • ');

    // Precio por litro (normal) -> double explícito
    final double precioPorLitro =
        (vol > 0) ? ((precio / (vol / 1000)).clamp(0.0, double.infinity) as double) : 0.0;

    // Flags para chips
    final esAlcoholica = _isAlcoholica(data);
    final esEnergizante = _isEnergizante(data);
    final esPallet = _isPallet(data);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de bebida'),
        actions: [
          IconButton(
            tooltip: 'Copiar info',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              final txt = '$nombre (${subtitle.isEmpty ? 'sin datos' : subtitle})';
              await Clipboard.setData(ClipboardData(text: txt));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Información copiada')),
                );
              }
            },
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.of(context).pop(); // vuelvo a la lista
                onEdit!.call();               // abre tu form existente
              },
            ),
          if (onDelete != null)
            PopupMenuButton<String>(
              tooltip: 'Más',
              onSelected: (v) {
                if (v == 'delete') {
                  Navigator.of(context).pop(); // cierro detalle
                  onDelete!.call();            // usa tu lógica de borrado (ya confirma)
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Foto grande con Hero
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Hero(
              tag: 'bebida_$bebidaId',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: (fotoUrl.isEmpty)
                    ? Container(
                        color: cs.surfaceContainerHighest.withOpacity(.6),
                        child: Icon(Icons.local_drink,
                            size: 64, color: cs.onSurfaceVariant),
                      )
                    : Image.network(fotoUrl, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            nombre,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
          if (!activo) ...[
            const SizedBox(height: 6),
            Text('Inactiva', style: TextStyle(color: cs.error)),
          ],
          const SizedBox(height: 14),

          // Bloque de precios (grande)
          _PriceWithCredentialBlock(
            comercioId: comercioId,
            precioBase: precio,
            promoPrecio: promoPrecio,
            money: _money,
          ),

          const SizedBox(height: 18),

          if (descripcion.isNotEmpty) ...[
            Text('Descripción', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(descripcion, style: TextStyle(height: 1.35, color: cs.onSurface)),
            const SizedBox(height: 18),
          ],

          // Fichas de info
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (marca.isNotEmpty) _chip(Icons.style, 'Marca: $marca'),
              if (categoria.isNotEmpty) _chip(Icons.category_outlined, 'Categoría: $categoria'),
              if (vol > 0) _chip(Icons.local_bar_outlined, 'Volumen: ${vol}ml'),
              if (vol > 0) _chip(Icons.stacked_line_chart, 'Precio/L: \$ ${_money(precioPorLitro.toDouble())}'),
              _chip(Icons.check_circle_outline, activo ? 'Activa' : 'Inactiva'),
              if (isPromo) _chip(Icons.local_offer, 'Tiene promo'),
              if (esAlcoholica) _chip(Icons.wine_bar, 'Alcohólica'),
              if (esEnergizante) _chip(Icons.bolt, 'Energizante'),
              if (esPallet) _chip(Icons.inventory_2_outlined, 'Pallet/Caja'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text),
      shape: const StadiumBorder(),
    );
  }
}

/// Bloque de precios para la vista de detalle (similar al de lista pero más grande)
class _PriceWithCredentialBlock extends StatelessWidget {
  const _PriceWithCredentialBlock({
    required this.comercioId,
    required this.precioBase,
    required this.money,
    this.promoPrecio,
  });

  final String comercioId;
  final double precioBase;
  final double? promoPrecio;
  final String Function(double) money;

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
        final winnerIsNormal = best == precioBase;

        Widget line({
          required String label,
          required double value,
          Color? color,
          bool highlight = false,
          bool strike = false,
          String? extraRight,
        }) {
          final style = TextStyle(
            fontSize: highlight ? 20 : 16,
            fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
            color: strike
                ? (color ?? cs.onSurface).withOpacity(.55)
                : (color ?? cs.onSurface),
            decoration: strike ? TextDecoration.lineThrough : null,
          );
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (extraRight != null) ...[
                    Text(
                      extraRight,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color ?? cs.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text('\$ ${money(value)}', style: style),
                ],
              ),
            ],
          );
        }

        final rows = <Widget>[
          line(label: 'Precio normal', value: precioBase, strike: best < precioBase),
          if (credPrice != null)
            line(
              label: 'Con tu credencial',
              value: credPrice,
              color: Colors.green,
              highlight: credPrice <= best + 0.0001,
              extraRight: '-${pct.toStringAsFixed(0)}%',
            ),
          if (promoPrecio != null)
            line(
              label: 'Precio promo',
              value: promoPrecio!,
              color: Colors.pink,
              highlight: promoPrecio! <= best + 0.0001,
            ),
        ];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
          ),
          child: Column(
            children: [
              ...rows.map((w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: w,
                  )),
              if (!winnerIsNormal)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      const Text('Mejor precio disponible',
                          style: TextStyle(fontWeight: FontWeight.w800)),
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