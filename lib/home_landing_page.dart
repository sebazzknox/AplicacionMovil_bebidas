import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'widgets/social_links_card.dart';
import 'comercios_page.dart' show ComerciosPage;      // ⬅️ solo la clase, no trae kIsAdmin
import 'ofertas_page.dart' show OfertasPage;
import 'admin_state.dart';                            // ⬅️ define adminMode y kIsAdmin globales
import 'admin_panel_page.dart';
import 'services/analytics_service.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'promos_destacadas.dart';
import 'widgets/animated_filter_chips.dart';
import 'widgets/promo_ticker.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

// PIN de administrador (podés cambiarlo cuando quieras)
const String kAdminPin = '1234';

/// Asegura sesión y asigna rol admin en Firestore
Future<void> ensureSignedInAndPromoteToAdmin() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
  final uid = auth.currentUser!.uid;

  await FirebaseFirestore.instance.collection('users').doc(uid).set(
    {
      'role': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
}

/// ====================== HOME LANDING ======================
class HomeLandingPage extends StatefulWidget {
  const HomeLandingPage({super.key});

  @override
  State<HomeLandingPage> createState() => _HomeLandingPageState();
}

class _HomeLandingPageState extends State<HomeLandingPage> {
  @override
  void initState() {
    super.initState();
    // registra apertura de la app
    AppAnalytics.appOpen();
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
  flexibleSpace: FlexibleSpaceBar(
    // En vez de usar title/titlePadding, armamos todo en el background
    background: Stack(
      fit: StackFit.expand,
      children: [
        // Fondo con gradiente que respeta el tema
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primaryContainer,
                cs.tertiaryContainer,
              ],
            ),
          ),
        ),

        // Contenido centrado: logo + subtítulo
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hacemos el logo más grande con un scale
              Transform.scale(
                scale: 1.7, // ↔️ ajustá si lo querés aún más grande
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
      ],
    ),
  ),
),

      const SliverToBoxAdapter(
        child: GreetingHeader(),
      ),

      // …tus otros slivers aquí
         


  


 // ✅ solo acá va el ; porque termina el return

          // -------- BANNER ADMIN ARRIBA (solo si adminMode = true) --------
          SliverToBoxAdapter(
            child: ValueListenableBuilder<bool>(
              valueListenable: adminMode,
              builder: (context, isAdmin, _) {
                if (!isAdmin) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withOpacity(.18),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                          onPressed: () {
                            adminMode.value = false;
                            kIsAdmin = false;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Modo admin desactivado')),
                            );
                          },
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

          // -------- Banner publicitario arriba del buscador --------
           SliverToBoxAdapter(child: _HomePromoBanner()),
                SliverToBoxAdapter(child:_GifPromoBanner()),

          // -------- Chips rápidos de promos --------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _PromoChipsRow(
                onTapChip: (context) {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const OfertasPage()));
                },
              ),
            ),
          ),
          

          // … por ejemplo después de los chips/promos
           const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: PromosDestacadas()),

          // -------- CONTENIDO ORIGINAL --------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Buscador
                  TextField(
                    readOnly: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ComerciosPage()),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Provincia, ciudad o comercio',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
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
                    subtitle: 'Ver comercios en el mapa (próximamente)',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mapa: próximamente ✨')),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Panel visible SOLO si admin activo
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
                              MaterialPageRoute(
                                  builder: (_) => const AdminPanelPage()),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),

                  // ---- Redes sociales
                  const SizedBox(height: 16),
Text(
  'Seguinos en redes sociales',
  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
),
const SocialLinksCard(
  facebookUrl: 'https://www.facebook.com/share/17JKBaM6Rs/',
  instagramUrl: 'https://www.instagram.com/descabiooficial?igsh=MWVqdDByamI0Z2JnOQ==',
  tiktokUrl: 'https://www.tiktok.com/@tu_usuario_tiktok',
 ),

                  Center(
                    child: TextButton.icon(
                      onPressed: () => _showAdminLogin(context),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Soy administrador'),
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

  // ========= LOGIN ADMIN por PIN =========
  void _showAdminLogin(BuildContext context) {
    if (adminMode.value == true || kIsAdmin) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.verified_user_outlined),
                title: Text('Sesión iniciada'),
                subtitle: Text('Ya estás en modo administrador'),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Salir de administrador'),
                onTap: () {
                  adminMode.value = false;
                  kIsAdmin = false;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Modo admin desactivado')),
                  );
                },
              ),
            ],
          ),
        ),
      );
      return;
    }

    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Acceso administrador'),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'PIN',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              if (pin == kAdminPin) {
                await ensureSignedInAndPromoteToAdmin();
                adminMode.value = true;
                kIsAdmin = true;
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Modo admin activado')),
                  );
                }
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('PIN incorrecto')),
                );
              }
            },
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
  }
}

/// ===== Banner publicitario (carrusel) =====
class _HomePromoBanner extends StatefulWidget {
  const _HomePromoBanner();

  @override
  State<_HomePromoBanner> createState() => _HomePromoBannerState();
}

class _HomePromoBannerState extends State<_HomePromoBanner> {
  final _pageCtrl = PageController(viewportFraction: .96);
  final _imgs = const <String>[
    'assets/banners/imagen2x1.jpg',
    // 'assets/banners/prueba.jpg',
  ];
  int _index = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  void _startAuto() {
    _t?.cancel();
    if (_imgs.length <= 1) return;
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _index = (_index + 1) % _imgs.length;
      _pageCtrl.animateToPage(
        _index,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
      setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemCount: _imgs.length,
                  itemBuilder: (_, i) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(_imgs[i], fit: BoxFit.cover),
                        IgnorePointer(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x33FFFFFF),
                                  Colors.transparent,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (_imgs.length > 1)
                Positioned(
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surface.withOpacity(.65),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          _imgs.length,
                          (i) => _Dot(active: i == _index),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: active ? 10 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline.withOpacity(.6),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}


/// ===== Fila de chips promocionales =====
class _PromoChipsRow extends StatelessWidget {
  final void Function(BuildContext) onTapChip;
  const _PromoChipsRow({required this.onTapChip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedFilterChips(
  tags: const [
    FilterTag(id: '2x1',   label: '2x1',          icon: Icons.local_drink_outlined),
    FilterTag(id: 'happy', label: 'Happy Hour',   icon: Icons.schedule_outlined),
    FilterTag(id: 'envio', label: 'Envío gratis', icon: Icons.local_shipping_outlined),
  ],
  onSelected: (tag) {
    // seguís haciendo lo mismo que antes
    onTapChip(context);

    // si querés actuar distinto según el chip:
    // if (tag.id == '2x1') { ... }
    // else if (tag.id == 'happy') { ... }
    // else if (tag.id == 'envio') { ... }
  },
);
  }
}

class _PromoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PromoChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onColor = Theme.of(context).colorScheme.onPrimaryContainer;
    return Material(
      color: color.withOpacity(.6),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: onColor),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: onColor)),
            ],
          ),
        ),
      ),
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
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
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
// --- Header con saludo dinámico y fondo con gradiente ---
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
    final text = Theme.of(context).textTheme;

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
                Text(_greeting(),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    )),
                const SizedBox(height: 4),
                Text('Descubrí ofertas y bebidas cerca de vos',
                    style: text.bodySmall?.copyWith(
                      color: cs.onPrimaryContainer.withOpacity(.85),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// --- Card con efecto “vidrio” (glassmorphism) ---
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

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
            border: Border.all(
              color: base.withOpacity(isDark ? .18 : .12),
              width: 1,
            ),
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

// Animación sutil de “presionado”
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
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  late final Animation<double> _scale =
      CurvedAnimation(parent: _c, curve: Curves.easeInOut)
          .drive(Tween(begin: 0.96, end: 1.04));

  @override
  void dispose() { _c.dispose(); super.dispose(); }

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
class _GifPromoBanner extends StatelessWidget {
  final _gifs = const [
    'assets/gifs/beer_ad.gif',
    'assets/gifs/drinks_offer.gif',
  ];


  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: PageView.builder(
        itemCount: _gifs.length,
        controller: PageController(viewportFraction: .9),
        itemBuilder: (_, i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                _gifs[i],
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }
}