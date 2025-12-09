// lib/contacto_card.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactoCard extends StatelessWidget {
  const ContactoCard({super.key});

  final String destinatario = "consultas@descabio.com";
  final String asunto = "Consulta para publicar comercio";

  Future<void> _abrirCorreo(BuildContext context) async {
    final encodedSubject = Uri.encodeComponent(asunto);

    // ============================
    // 1) Intentar abrir GMAIL APP
    // ============================
    final Uri gmailApp = Uri.parse(
      "googlegmail://co?to=$destinatario&subject=$encodedSubject",
    );

    if (await canLaunchUrl(gmailApp)) {
      await launchUrl(gmailApp, mode: LaunchMode.externalApplication);
      return;
    }

    // ============================
    // 2) Intentar abrir OUTLOOK APP
    // ============================
    final Uri outlookApp = Uri.parse(
      "ms-outlook://compose?to=$destinatario&subject=$encodedSubject",
    );

    if (await canLaunchUrl(outlookApp)) {
      await launchUrl(outlookApp, mode: LaunchMode.externalApplication);
      return;
    }

    // ===============================================
    // 3) Intentar abrir el selector universal MAILTO:
    // ===============================================
    final Uri mailtoUri = Uri(
      scheme: 'mailto',
      path: destinatario,
      queryParameters: {"subject": asunto},
    );

    if (await canLaunchUrl(mailtoUri)) {
      await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      return;
    }

    // ================================================
    // 4) Fallback TOTAL → Abrir Gmail Web en redactar
    // ================================================
    final Uri gmailWeb = Uri.parse(
      "https://mail.google.com/mail/?view=cm&fs=1&to=$destinatario&su=$encodedSubject",
    );

    if (!await launchUrl(gmailWeb, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo abrir ningún cliente de correo."),
          ),
        );
      }
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
              onPressed: () => _abrirCorreo(context),
              icon: const Icon(Icons.email_outlined),
              label: const Text('Contactanos'),
            ),
          ],
        ),
      ),
    );
  }
}
