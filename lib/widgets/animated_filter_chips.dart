// lib/widgets/animated_filter_chips.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class FilterTag {
  final String id;
  final String label;
  final IconData icon;
  const FilterTag({required this.id, required this.label, required this.icon});
}

class AnimatedFilterChips extends StatefulWidget {
  final List<FilterTag> tags;
  final ValueChanged<FilterTag>? onSelected;
  final EdgeInsets padding;
  final int? initialIndex;

  const AnimatedFilterChips({
    super.key,
    required this.tags,
    this.onSelected,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
    this.initialIndex,
  });

  @override
  State<AnimatedFilterChips> createState() => _AnimatedFilterChipsState();
}

class _AnimatedFilterChipsState extends State<AnimatedFilterChips>
    with TickerProviderStateMixin {
  late final AnimationController _shineCtrl;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIndex;
    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _shineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: widget.padding,
      child: Row(
        children: List.generate(widget.tags.length, (i) {
          final tag = widget.tags[i];
          final isSel = _selected == i;
          return _ChipItem(
            tag: tag,
            isSelected: isSel,
            shine: _shineCtrl,
            onTap: () {
              setState(() => _selected = i);
              widget.onSelected?.call(tag);
            },
          );
        }).expand((w) sync* {
          yield w;
          yield const SizedBox(width: 10);
        }).toList(),
      ),
    );
  }
}

class _ChipItem extends StatefulWidget {
  final FilterTag tag;
  final bool isSelected;
  final AnimationController shine;
  final VoidCallback onTap;
  const _ChipItem({
    required this.tag,
    required this.isSelected,
    required this.shine,
    required this.onTap,
  });

  @override
  State<_ChipItem> createState() => _ChipItemState();
}

class _ChipItemState extends State<_ChipItem> with TickerProviderStateMixin {
  late final AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.isSelected;
    final t = widget.shine.value;

    final baseGrad = LinearGradient(
      colors: sel
          ? const [Color(0xFF8B5CF6), Color(0xFFF472B6), Color(0xFF60A5FA)]
          : const [Color(0xFFEDE9FE), Color(0xFFF5E1F7)],
      transform: GradientRotation(2 * math.pi * t * (sel ? 1.0 : 0.2)),
      begin: Alignment(-1 + 2 * t, 0),
      end: Alignment(1 - 2 * t, 0),
    );

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: 1 - _pressCtrl.value,
        duration: const Duration(milliseconds: 160),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: baseGrad,
            borderRadius: BorderRadius.circular(24),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
            border: sel
                ? Border.all(color: Colors.white.withOpacity(0.7), width: 1.2)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.tag.icon,
                size: 18,
                color: sel ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : const Color(0xFF374151),
                ),
                child: Text(widget.tag.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}