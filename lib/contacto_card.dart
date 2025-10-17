// lib/contacto_card.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactoCard extends StatelessWidget {
  const ContactoCard({super.key});

  Future<void> _abrirCorreo() async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: 'desbebidas@consultas.com',
      query: Uri.encodeFull('subject=Consulta para publicar comercio'),
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'No se pudo abrir el cliente de correo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: cs.primaryContainer.withOpacity(.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '¿Querés publicar tu comercio, punto de venta o distribuidora?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _abrirCorreo,
              icon: const Icon(Icons.email_outlined),
              label: const Text('Contactanos'),
            ),
          ],
        ),
      ),
    );
  }
}