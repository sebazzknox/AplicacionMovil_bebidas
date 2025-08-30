// lib/widgets/social_follow_card.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialFollowCard extends StatelessWidget {
  final String? facebookUrl;
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? title;

  const SocialFollowCard({
    super.key,
    this.facebookUrl,
    this.instagramUrl,
    this.tiktokUrl,
    this.title,
  });

  bool get _hasContent =>
      (facebookUrl ?? '').isNotEmpty ||
      (instagramUrl ?? '').isNotEmpty ||
      (tiktokUrl ?? '').isNotEmpty;

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasContent) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title ?? 'Seguinos en redes sociales',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if ((facebookUrl ?? '').isNotEmpty)
                  _SocialPill(
                    label: 'Facebook',
                    icon: const FaIcon(FontAwesomeIcons.facebookF, size: 18),
                    onTap: () => _open(context, facebookUrl!),
                  ),
                if ((instagramUrl ?? '').isNotEmpty)
                  _SocialPill(
                    label: 'Instagram',
                    icon: const FaIcon(FontAwesomeIcons.instagram, size: 18),
                    onTap: () => _open(context, instagramUrl!),
                  ),
                if ((tiktokUrl ?? '').isNotEmpty)
                  _SocialPill(
                    label: 'TikTok',
                    icon: const FaIcon(FontAwesomeIcons.tiktok, size: 18),
                    onTap: () => _open(context, tiktokUrl!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialPill extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  const _SocialPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      shape: StadiumBorder(
        side: BorderSide(color: cs.outlineVariant.withOpacity(.5)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          // compacto y limpio
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(color: cs.onSurface.withOpacity(.8)),
                child: icon,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}