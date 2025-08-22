import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_landing_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _scale = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _c, curve: Curves.easeIn);

    _c.forward();

    // Pequeño delay y pasamos al home
    Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => const HomeLandingPage(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primaryContainer.withOpacity(.9),
              cs.surface,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Manchones / brillos “barrio vibe”
            Positioned(
              top: -40, left: -20,
              child: _blob(cs.primary.withOpacity(.15), 180),
            ),
            Positioned(
              bottom: -50, right: -30,
              child: _blob(cs.secondary.withOpacity(.12), 220),
            ),

            // Centro: logo + subtítulo animados
            Center(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) {
                  return Opacity(
                    opacity: _fade.value,
                    child: Transform.scale(
                      scale: .8 + (_scale.value * .25), // pequeño “pop”
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Texto con gradiente tipo graffiti/pop
                          ShaderMask(
                            shaderCallback: (rect) => const LinearGradient(
                              colors: [Color(0xFF7C4DFF), Color(0xFFFF4081)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(rect),
                            child: Text(
                              'DESCABIO',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.bangers( // look callejero
                                fontSize: 52,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700,
                                color: Colors.white, // se reemplaza por shader
                                height: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tienda de bebidas',
                            style: GoogleFonts.montserratAlternates(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface.withOpacity(.70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Pie: mini “loading”
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Cargando...',
                      style: TextStyle(color: cs.onSurface.withOpacity(.6)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size),
        boxShadow: [
          BoxShadow(color: color, blurRadius: 40, spreadRadius: 10),
        ],
      ),
    );
  }
}