import 'dart:ui';
import 'package:flutter/material.dart';

class GlassSearchField extends StatelessWidget {
  final String hintText;
  final VoidCallback onTap;
  const GlassSearchField({super.key, required this.hintText, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: cs.surface.withOpacity(.45),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.search, color: cs.onSurface.withOpacity(.7)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hintText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withOpacity(.7),
                          ),
                    ),
                  ),
                  Icon(Icons.tune_rounded, color: cs.onSurface.withOpacity(.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}