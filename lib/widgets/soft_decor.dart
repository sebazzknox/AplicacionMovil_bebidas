import 'dart:ui';
import 'package:flutter/material.dart';

/// Orbes suaves de color para el header
class SoftOrbs extends StatelessWidget {
  const SoftOrbs({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Stack(
        children: [
          // Orb grande arriba-izq
          Positioned(
            top: -40, left: -30,
            child: _Orb(
              size: 160,
              colors: [cs.primary.withOpacity(.35), cs.tertiary.withOpacity(.25)],
            ),
          ),
          // Orb mediano arriba-der
          Positioned(
            top: 10, right: -20,
            child: _Orb(
              size: 120,
              colors: [cs.secondary.withOpacity(.28), cs.primary.withOpacity(.22)],
            ),
          ),
          // Orb pequeño centro
          Positioned(
            top: 90, left: 120,
            child: _Orb(
              size: 80,
              colors: [cs.tertiary.withOpacity(.22), cs.secondary.withOpacity(.18)],
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final List<Color> colors;
  const _Orb({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }
}

/// Ola inferior que suaviza el corte con el contenido
class BottomWave extends StatelessWidget {
  final double height;
  const BottomWave({super.key, this.height = 42});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Positioned(
      bottom: -1, left: 0, right: 0,
      child: SizedBox(
        height: height,
        child: CustomPaint(painter: _BottomWavePainter(color: bg)),
      ),
    );
  }
}

class _BottomWavePainter extends CustomPainter {
  final Color color;
  _BottomWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.fill;
    final h = size.height, w = size.width;
    final path = Path()
      ..moveTo(0, h)
      ..quadraticBezierTo(w * .20, h * .30, w * .50, h * .55)
      ..quadraticBezierTo(w * .80, h * .80, w, h * .35)
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _BottomWavePainter old) => false;
}