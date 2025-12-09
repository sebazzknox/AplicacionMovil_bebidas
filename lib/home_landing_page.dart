// lib/home_landing_page.dart
import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth/auth_gate.dart';
import 'splash_screen.dart';
import 'contacto_card.dart';

import 'aviso_legal.dart';
import 'admin_panel_page.dart';
import 'admin_state.dart';
import 'comercios_page.dart' show ComerciosPage;
import 'ofertas_page.dart' show OfertasPage;
import 'promos_destacadas.dart';
import 'services/analytics_service.dart';
import 'widgets/glass_search_field.dart';
import 'widgets/soft_decor.dart';
import 'widgets/social_links_card.dart';
import 'mapa_page.dart';
import 'mayoristas_page.dart' show MayoristasPage;
import 'credencial_page.dart';

// ⬇️ NUEVO: aviso legal (se muestra una sola vez)
import 'widgets/legal_disclaimer.dart';

const String ADMIN_PIN =
    String.fromEnvironment('ADMIN_PIN', defaultValue: '123456');

Future<void> ensureSignedInAndPromoteToAdmin() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
  final uid = auth.currentUser!.uid;
  await FirebaseFirestore.instance.collection('users').doc(uid).set(
    {'role': 'admin', 'isAdmin': true, 'updatedAt': FieldValue.serverTimestamp()},
    SetOptions(merge: true),
  );
}

Future<bool> _signInAdminAccountAndSetFlags(BuildContext context) async {
  try {
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'admin@hotmail.com',
      password: '123456',
    );
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'role': 'admin',
      'isAdmin': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar sesión de admin: $e')),
      );
    }
    return false;
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(appBar: null, body: HomeLandingPage());
  }
}

class HomeLandingPage extends StatefulWidget {
  const HomeLandingPage({super.key});
  @override
  State<HomeLandingPage> createState() => _HomeLandingPageState();
}

class _HomeLandingPageState extends State<HomeLandingPage> {
  @override
  void initState() {
    super.initState();
    AppAnalytics.appOpen();

    // ⬇️ NUEVO: Mostrar el aviso legal la primera vez
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showLegalDisclaimerOnce(context);
    });
  }

  Future<void> _logout(BuildContext context) async {
    adminMode.value = false;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate(home: SplashScreen())),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: cs.surface,
            actions: [
              IconButton(
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Cerrar sesión'),
                      content: const Text('¿Seguro que querés salir de tu cuenta?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await _logout(context);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [cs.primaryContainer, cs.tertiaryContainer],
                      ),
                    ),
                  ),
                  const SoftOrbs(),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: 1.7,
                          child: const DescabioLogoTitle(),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'La mejor app para distribución de bebidas',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: cs.onPrimaryContainer.withOpacity(.95),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: .2,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const BottomWave(height: 42),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: GreetingHeader()),

          SliverToBoxAdapter(
            child: ValueListenableBuilder<bool>(
              valueListenable: adminMode,
              builder: (context, isAdmin, _) {
                if (!isAdmin) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user, color: Colors.white),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Admin activo',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withOpacity(.18),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          onPressed: () async => _logout(context),
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Salir'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ========= HERO: carrusel del GIF “brindis” =========
          const SliverToBoxAdapter(child: _GifHeroBanner()),

          // ===== Chips (colores adaptados a la app) =====
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.06),
                      blurRadius: 18,
                      spreadRadius: -8,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: _PromoChipsRow(
                  onTapChip: (ctx) {
                    // se usa para 'ofertas'; los otros se navegan directo
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(builder: (_) => const OfertasPage()),
                    );
                  },
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          const SliverToBoxAdapter(child: PromosDestacadas()),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassSearchField(
                    hintText: 'Provincia, ciudad o comercio',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ComerciosPage()),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _ActionCard(
                    icon: Icons.store_mall_directory_outlined,
                    title: 'Explorar comercios',
                    subtitle: 'Buscá por nombre, ciudad o provincia',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ComerciosPage()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _ActionCard(
                    icon: Icons.local_offer_outlined,
                    title: 'Ofertas',
                    subtitle: 'Promos destacadas',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OfertasPage()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _ActionCard(
                    icon: Icons.map_outlined,
                    title: 'Mapa',
                    subtitle: 'Ver comercios en el mapa',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MapaPage()),
                    ),
                  ),

                  const SizedBox(height: 12),

                  _ActionCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'Mayoristas',
                    subtitle: 'Distribuidores y ventas por volumen',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MayoristasPage()),
                    ),
                  ),

                  const SizedBox(height: 12),

                  _ActionCard(
                    icon: Icons.badge_outlined,
                    title: 'Mi credencial',
                    subtitle: 'Descuentos y QR',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CredencialPage()),
                    ),
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: adminMode,
                    builder: (context, isAdmin, _) {
                      if (!isAdmin) return const SizedBox.shrink();
                      return Column(
                        children: [
                          _ActionCard(
                            icon: Icons.space_dashboard_outlined,
                            title: 'Panel de administración',
                            subtitle: 'Comercios · Ofertas · Stock · Finanzas',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminPanelPage()),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  const Text('Seguinos en redes sociales',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SocialLinksCard(
                    facebookUrl: 'https://www.facebook.com/share/17JKBaM6Rs/',
                    instagramUrl:
                        'https://www.instagram.com/descabiooficial?igsh=MWVqdDByamI0Z2JnOQ==',
                    tiktokUrl: 'https://www.tiktok.com/@tu_usuario_tiktok',
                  ),
                  const SizedBox(height: 12),
                  const ContactoCard(),

                  // ⬇️ NUEVO: Botón para abrir el aviso legal manualmente
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Aviso legal'),
                      onPressed: () {
                      Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AvisoLegalPage()),
                    );
                    },

                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showAdminLogin(BuildContext context) {
    final isAdmin = AdminState.isAdmin(context);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        if (isAdmin) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    leading: Icon(Icons.verified_user_outlined),
                    title: Text('Sesión iniciada'),
                    subtitle: Text('Ya estás en modo administrador'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Salir de modo admin'),
                    onPressed: () async {
                      adminMode.value = false;
                      try {
                        await FirebaseAuth.instance.signOut();
                      } catch (_) {}
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sesión admin cerrada')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        }

        final pinCtrl = TextEditingController();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Ingresar PIN de administrador'),
                  subtitle: Text('Sólo personal autorizado'),
                ),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'PIN',
                    prefixIcon: Icon(Icons.password),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('Acceder'),
                        onPressed: () async {
                          final pin = pinCtrl.text.trim();
                          if (pin == ADMIN_PIN) {
                            final ok = await _signInAdminAccountAndSetFlags(context);
                            if (ok) {
                              adminMode.value = true;
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Modo admin activado')),
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('PIN incorrecto')),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ===== HERO: carrusel del GIF (16:9, protagonista) =====
class _GifHeroBanner extends StatelessWidget {
  const _GifHeroBanner();

  // Solo el brindis como “centro”
  final _gifs = const [
    'assets/gifs/brindis.gif', // asegurate de tenerlo en assets y en pubspec.yaml
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cons) {
      final width = cons.maxWidth;
      const aspect = 16 / 9;
      final cardWidth = width * .96;
      final height = cardWidth / aspect;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: SizedBox(
          height: height,
          child: PageView.builder(
            itemCount: _gifs.length,
            controller: PageController(viewportFraction: .96),
            itemBuilder: (_, i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _PromoGifCard(asset: _gifs[i], width: cardWidth, height: height),
              );
            },
          ),
        ),
      );
    });
  }
}

class _PromoGifCard extends StatelessWidget {
  final String asset;
  final double width;
  final double height;
  const _PromoGifCard({
    required this.asset,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheW = (width * dpr).round();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            cacheWidth: cacheW,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      cs.surface.withOpacity(.06),
                      cs.surface.withOpacity(.18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Row de accesos (colores adaptados a la app) =====
class _PromoChipsRow extends StatelessWidget {
  final void Function(BuildContext) onTapChip; // se usa para 'ofertas'
  const _PromoChipsRow({required this.onTapChip});

  @override
  Widget build(BuildContext context) {
    // Paleta morado/rosa/azul en sintonía con el header
    final items = const [
      _ChipData(
        id: 'ofertas',
        label: 'Ofertas de hoy',
        icon: Icons.local_fire_department_outlined,
        gradientA: Color.fromARGB(255, 255, 157, 77),
        gradientB: Color(0xFFFF4081),
      ),
      _ChipData(
        id: 'cerca',
        label: 'Cerca tuyo',
        icon: Icons.near_me_outlined,
        gradientA: Color(0xFF00B0FF),
        gradientB: Color(0xFF7C4DFF),
      ),
      _ChipData(
        id: 'mayoristas',
        label: 'Mayoristas',
        icon: Icons.inventory_2_outlined,
        gradientA: Color(0xFFFF6E40),
        gradientB: Color(0xFFFF4081),
      ),
    ];

    return SizedBox(
      height: 80,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final d = items[i];
          return _NeoActionTile(
            data: d,
            onTap: () {
              switch (d.id) {
                case 'ofertas':
                  onTapChip(context); // abre OfertasPage
                  break;
                case 'cerca':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapaPage()),
                  );
                  break;
                case 'mayoristas':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MayoristasPage()),
                  );
                  break;
              }
            },
          );
        },
      ),
    );
  }
}

class _ChipData {
  final String id;
  final String label;
  final IconData icon;
  final Color gradientA;
  final Color gradientB;
  const _ChipData({
    required this.id,
    required this.label,
    required this.icon,
    required this.gradientA,
    required this.gradientB,
  });
}

class _NeoActionTile extends StatefulWidget {
  final _ChipData data;
  final VoidCallback onTap;
  const _NeoActionTile({required this.data, required this.onTap});

  @override
  State<_NeoActionTile> createState() => _NeoActionTileState();
}

class _NeoActionTileState extends State<_NeoActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = widget.data;

    final darkShadow = Colors.black.withOpacity(.10);
    final lightShadow = Colors.white.withOpacity(.75);

    return AnimatedScale(
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      scale: _pressed ? 0.985 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: const BoxConstraints(minWidth: 180),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outlineVariant.withOpacity(.20)),
              boxShadow: [
                BoxShadow(color: darkShadow, blurRadius: _pressed ? 8 : 16, offset: const Offset(8, 8)),
                BoxShadow(color: lightShadow, blurRadius: _pressed ? 6 : 14, offset: const Offset(-6, -6)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícono ahora en un CUADRADO REDONDEADO (no círculo)
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: [d.gradientA, d.gradientB]),
                    boxShadow: [
                      BoxShadow(
                        color: d.gradientB.withOpacity(.35),
                        blurRadius: _pressed ? 6 : 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const SizedBox.shrink(),
                ),
                // Ícono blanco superpuesto (para no usar Stack)
                Transform.translate(
                  offset: const Offset(-40, 0),
                  child: Icon(d.icon, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    d.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientCircleIcon extends StatelessWidget {
  final IconData icon;
  final Color a;
  final Color b;
  const _GradientCircleIcon({required this.icon, required this.a, required this.b});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [a, b]),
      ),
      foregroundDecoration: const BoxDecoration(shape: BoxShape.circle),
      child: const Icon(Icons.circle, size: 0),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withOpacity(.6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: cs.primaryContainer,
                child: Icon(icon, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return '¡Buen día!';
    if (h < 19) return '¡Buenas tardes!';
    return '¡Buenas noches!';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withOpacity(.9),
            cs.secondaryContainer.withOpacity(.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.onPrimaryContainer.withOpacity(.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_drink, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Descubrí ofertas y bebidas cerca de vos',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onPrimaryContainer.withOpacity(.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const GlassCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white : Colors.black;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: base.withOpacity(isDark ? .08 : .06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: base.withOpacity(isDark ? .18 : .12), width: 1),
          ),
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

    if (onTap == null) return card;

    return _TapScale(
      scale: .98,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _TapScale extends StatefulWidget {
  final Widget child;
  final double scale;
  const _TapScale({required this.child, this.scale = .98});
  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        scale: _down ? widget.scale : 1,
        child: widget.child,
      ),
    );
  }
}

class DescabioLogoTitle extends StatefulWidget {
  const DescabioLogoTitle({super.key});
  @override
  State<DescabioLogoTitle> createState() => _DescabioLogoTitleState();
}

class _DescabioLogoTitleState extends State<DescabioLogoTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
        ..repeat(reverse: true);

  late final Animation<double> _scale =
      CurvedAnimation(parent: _c, curve: Curves.easeInOut).drive(Tween(begin: 0.96, end: 1.04));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'app_logo',
      child: ScaleTransition(
        scale: _scale,
        child: ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFF7C4DFF), Color(0xFFFF4081)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(r),
          child: Text(
            'DESCABIO',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.bangers(
              fontSize: 26,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}