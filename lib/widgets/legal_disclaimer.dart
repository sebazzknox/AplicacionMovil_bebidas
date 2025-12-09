import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDisclaimerKey = 'disclaimer_ack_v2';

const String kDisclaimerText = 
  'Cada auspiciante es gestionado por su respectivo titular, '
  'quien es responsable por los productos, atención al cliente, '
  'entregas y políticas comerciales.\n\n'
  'DESCABIO solo proporciona la infraestructura tecnológica y de '
  'publicidad para facilitar la venta online.';

/// Lanza un diálogo informativo la PRIMERA vez.
/// Si ya se aceptó, no vuelve a aparecer.
Future<void> showLegalDisclaimerOnce(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getBool(_kDisclaimerKey) ?? false;
  if (seen) return;

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: const Text('Aviso importante'),
        content: const Text(kDisclaimerText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Entendido'),
            onPressed: () async {
              await prefs.setBool(_kDisclaimerKey, true);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      );
    },
  );
}

/// Alternativa: banner superior (por si querés mostrarlo en una pantalla fija)
void showLegalBanner(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentMaterialBanner();
  messenger.showMaterialBanner(
    MaterialBanner(
      content: const Text(kDisclaimerText),
      leading: const Icon(Icons.info_outline),
      actions: [
        TextButton(
          onPressed: () => messenger.hideCurrentMaterialBanner(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
