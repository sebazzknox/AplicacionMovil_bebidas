import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 NUEVO: auth para login anónimo

import 'comercios_page.dart';
import 'ofertas_page.dart';
import 'comercios_page.dart' as cp;
import 'admin_state.dart';
import 'admin_panel_page.dart';

// PIN de administrador (podés cambiarlo cuando quieras)
const String kAdminPin = '1234';

/// 👇 NUEVO: asegura sesión y asigna rol admin en Firestore
Future<void> ensureSignedInAndPromoteToAdmin() async {
  final auth = FirebaseAuth.instance;

  // si no hay usuario, crea sesión anónima
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }

  final uid = auth.currentUser!.uid;

  // setea/mergea rol 'admin' en users/{uid}
  await FirebaseFirestore.instance.collection('users').doc(uid).set(
    {
      'role': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
}

class HomeLandingPage extends StatelessWidget {
  const HomeLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: cs.surface,
            title: const Text('Bebidas cerca de vos'),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primaryContainer, cs.surface],
                  ),
                ),
              ),
            ),
          ),

          // -------- BANNER ADMIN ARRIBA (solo si adminMode = true) --------
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          onPressed: () {
                            adminMode.value = false;
                            cp.kIsAdmin = false;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Modo admin desactivado')),
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
          const SliverToBoxAdapter(child: _HomePromoBanner()),

          // -------- Chips rápidos de promos --------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _PromoChipsRow(
                onTapChip: (context) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OfertasPage()));
                },
              ),
            ),
          ),

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
                              MaterialPageRoute(builder: (_) => const AdminPanelPage()),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
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

  // ========= LOGIN ADMIN por PIN (ACTUALIZADO) =========
  void _showAdminLogin(BuildContext context) {
    if (adminMode.value == true || cp.kIsAdmin) {
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
                  cp.kIsAdmin = false;
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

    // Si no está logueado como admin, pedimos PIN
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
                // 👇 Loguea anónimo (si hace falta) y asigna rol admin
                await ensureSignedInAndPromoteToAdmin();

                adminMode.value = true;
                cp.kIsAdmin = true;

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

/// ===== Banner publicitario PRO (carrusel local + fade + indicadores) =====
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _PromoChip(
            label: '2x1',
            icon: Icons.local_drink_outlined,
            color: cs.primaryContainer,
            onTap: () => onTapChip(context),
          ),
          const SizedBox(width: 8),
          _PromoChip(
            label: 'Happy Hour',
            icon: Icons.schedule_outlined,
            color: cs.secondaryContainer,
            onTap: () => onTapChip(context),
          ),
          const SizedBox(width: 8),
          _PromoChip(
            label: 'Envío gratis',
            icon: Icons.local_shipping_outlined,
            color: cs.tertiaryContainer,
            onTap: () => onTapChip(context),
          ),
        ],
      ),
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