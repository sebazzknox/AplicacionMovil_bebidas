// lib/widgets/commerce_tile.dart
import 'package:flutter/material.dart';

class CommerceTile extends StatelessWidget {
  const CommerceTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.isOpen,
    this.hasPromo = false,
    this.distanceKm,
    required this.onTap,
    this.onLongPress,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.onCall,
    this.onWhatsApp,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;

  final bool isOpen;
  final bool hasPromo;
  final double? distanceKm;

  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  // Favoritos
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  // Acciones rápidas
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;

  static const double _avatarSize = 86;

  // ---------- Helpers (métodos privados, sin problemas de orden) ----------
  Widget _placeholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primaryContainer, cs.secondaryContainer],
        ),
      ),
      child: SizedBox(
        width: _avatarSize,
        height: _avatarSize,
        child: Icon(Icons.store, color: cs.onPrimaryContainer, size: 30),
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    final r = BorderRadius.circular(16);
    final img = (imageUrl != null && imageUrl!.isNotEmpty)
        ? Image.network(
            imageUrl!,
            width: _avatarSize,
            height: _avatarSize,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(context),
          )
        : _placeholder(context);

    return ClipRRect(borderRadius: r, child: img);
  }

  Widget _stateChip(BuildContext context) {
    final open = isOpen;
    final color = open ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Text(
        open ? 'Abierto' : 'Cerrado',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)
            .copyWith(color: color),
      ),
    );
  }

  Widget _promoChip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withOpacity(.60),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_offer_outlined, size: 14, color: cs.onTertiaryContainer),
          const SizedBox(width: 4),
          Text('Promo',
              style: TextStyle(
                color: cs.onTertiaryContainer,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              )),
        ],
      ),
    );
  }

  Widget _distanceChip(BuildContext context, double km) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${km.toStringAsFixed(1)} km',
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: 12.8,
        ),
      ),
    );
  }

  Widget _heartButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filled = isFavorite;
    return InkResponse(
      onTap: onToggleFavorite,
      radius: 22,
      child: Icon(
        filled ? Icons.favorite : Icons.favorite_border,
        size: 22,
        color: filled ? cs.primary : cs.outline,
      ),
    );
  }

  Widget _actionIcon(BuildContext context, IconData icon, VoidCallback onPressed) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceVariant.withOpacity(.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // barrita de estado a la izquierda
            Container(
              width: 6,
              height: _avatarSize,
              decoration: BoxDecoration(
                color: (isOpen ? Colors.green : Colors.red).withOpacity(.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 12),

            // avatar
            _avatar(context),
            const SizedBox(width: 14),

            // contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // título + chevron + favorito
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (onToggleFavorite != null) _heartButton(context),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                    ],
                  ),

                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // chips de status / promo / distancia
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _stateChip(context),
                      if (hasPromo) _promoChip(context),
                      if (distanceKm != null) _distanceChip(context, distanceKm!),
                    ],
                  ),

                  // acciones rápidas
                  if (onCall != null || onWhatsApp != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (onCall != null) ...[
                          _actionIcon(context, Icons.call, onCall!),
                          const SizedBox(width: 8),
                        ],
                        if (onWhatsApp != null) ...[
                          // No existe Icons.whatsapp: usamos un chat genérico
                          _actionIcon(context, Icons.chat_outlined, onWhatsApp!),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}