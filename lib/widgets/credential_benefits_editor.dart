// lib/widgets/credential_benefits_editor.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/credenciales_config_service.dart';

/// Editor embebible para:
/// - aceptaCredencial (switch)
/// - beneficios por tier (números, en %)
///
/// Guarda en el comercio:
///   aceptaCredencial: bool
///   beneficios: {
///     'CLASICA': { 'pct': 10 },
///     'PLUS'   : { 'pct': 20 },
///     'PREMIUM': { 'pct': 30 },
///   }
class CredentialBenefitsEditor extends StatefulWidget {
  final bool initialAcepta;
  /// Puede venir en cualquiera de estos formatos (ambos soportados):
  ///   1) { 'CLASICA': 10, 'PLUS': 20, 'PREMIUM': 30 }
  ///   2) { 'CLASICA': {'pct':10}, 'PLUS': {'pct':20}, 'PREMIUM': {'pct':30} }
  final Map<String, dynamic>? initialBeneficios;

  const CredentialBenefitsEditor({
    super.key,
    this.initialAcepta = false,
    this.initialBeneficios,
  });

  @override
  State<CredentialBenefitsEditor> createState() => CredentialBenefitsEditorState();
}

class CredentialBenefitsEditorState extends State<CredentialBenefitsEditor> {
  bool _acepta = false;
  final Map<String, TextEditingController> _pctCtrl = {
    'CLASICA': TextEditingController(),
    'PLUS': TextEditingController(),
    'PREMIUM': TextEditingController(),
  };
  bool _loadingDefaults = true;

  @override
  void initState() {
    super.initState();
    _acepta = widget.initialAcepta;
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    setState(() => _loadingDefaults = true);

    // Defaults globales (devuelve {CLASICA: 10, PLUS: 20, PREMIUM: 30})
    final defaults = await CredencialesConfigService.loadGlobalDefaults();

    // Merge con beneficios iniciales si vinieron
    final fromInitial = <String, double>{};
    (widget.initialBeneficios ?? {}).forEach((k, v) {
      final tier = k.toString().toUpperCase();
      if (v is num) {
        fromInitial[tier] = v.toDouble();
      } else if (v is Map) {
        final n = (v['pct'] as num?)?.toDouble();
        if (n != null) fromInitial[tier] = n;
      }
    });

    for (final tier in _pctCtrl.keys) {
      final val = fromInitial[tier] ?? defaults[tier] ?? 0.0;
      _pctCtrl[tier]!.text = val.toStringAsFixed(0);
    }

    setState(() => _loadingDefaults = false);
  }

  /// Devuelve el payload listo para .set(.., merge:true) del comercio
  /// con la forma anidada que espera el servicio:
  /// beneficios.{TIER}.pct
  Map<String, dynamic> buildPayload() {
    if (!_acepta) {
      return {
        'aceptaCredencial': false,
        'beneficios': FieldValue.delete(), // limpiamos si estaba
      };
    }

    double read(String tier) =>
        double.tryParse(_pctCtrl[tier]!.text.trim().replaceAll(',', '.')) ?? 0.0;

    final map = <String, Map<String, num>>{};
    for (final tier in _pctCtrl.keys) {
      final v = read(tier);
      if (v > 0) map[tier] = {'pct': v}; // ← estructura anidada
    }

    return {
      'aceptaCredencial': true,
      'beneficios': map,
    };
  }

  @override
  void dispose() {
    for (final c in _pctCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          value: _acepta,
          onChanged: (v) => setState(() => _acepta = v),
          title: const Text('Aceptar credencial Descabio'),
          subtitle: const Text('Habilitá descuentos por categoría (Clásica / Plus / Premium)'),
        ),
        if (_acepta) ...[
          if (_loadingDefaults)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
          _TierInputRow(label: 'CLÁSICA', ctrl: _pctCtrl['CLASICA']!),
          const SizedBox(height: 8),
          _TierInputRow(label: 'PLUS', ctrl: _pctCtrl['PLUS']!),
          const SizedBox(height: 8),
          _TierInputRow(label: 'PREMIUM', ctrl: _pctCtrl['PREMIUM']!),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loadDefaults,
              icon: const Icon(Icons.restore),
              label: const Text('Restablecer valores globales'),
            ),
          ),
          Divider(color: cs.outlineVariant),
        ],
      ],
    );
  }
}

class _TierInputRow extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const _TierInputRow({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: const InputDecoration(
              labelText: 'Descuento',
              suffixText: '%',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) {
              final n = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (n == null) return 'Inválido';
              if (n < 0 || n > 90) return '0–90';
              return null;
            },
          ),
        ),
      ],
    );
  }
}