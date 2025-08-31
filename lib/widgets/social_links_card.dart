import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialLinksCard extends StatelessWidget {
  final String facebookUrl;
  final String instagramUrl;
  final String tiktokUrl;

  const SocialLinksCard({
    super.key,
    required this.facebookUrl,
    required this.instagramUrl,
    required this.tiktokUrl,
  });

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("No se pudo abrir $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Seguinos en redes sociales",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildButton(
                context,
                icon: FontAwesomeIcons.facebookF,
                label: "Facebook",
                color: Colors.blueAccent,
                onTap: () => _launch(facebookUrl),
              ),
              _buildButton(
                context,
                icon: FontAwesomeIcons.instagram,
                label: "Instagram",
                color: Colors.pinkAccent,
                onTap: () => _launch(instagramUrl),
              ),
              _buildButton(
                context,
                icon: FontAwesomeIcons.tiktok,
                label: "TikTok",
                color: Colors.black,
                onTap: () => _launch(tiktokUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withOpacity(.15),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}