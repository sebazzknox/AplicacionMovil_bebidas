import 'package:flutter/material.dart';
import 'comercios_page.dart';
import 'ofertas_page.dart';
import 'comercios_mock_page.dart';
import 'comercios_page.dart' as cp;
import 'admin_state.dart';
// acceso al panel
import 'admin_panel_page.dart';

// PIN de administrador (podés cambiarlo cuando quieras)
const String kAdminPin = '1234';

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

  // ========= LOGIN ADMIN por PIN =========
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

    final pinCtrl = TextEditingController();

    Future<void> tryLogin(BuildContext ctx) async {
      final pin = pinCtrl.text.trim();
      if (pin == kAdminPin) {
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
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.admin_panel_settings_outlined),
                title: Text('Acceso administrador'),
                subtitle: Text('Ingresá tu PIN para gestionar'),
              ),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => tryLogin(ctx),
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(Icons.password_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Ingresar'),
                    onPressed: () => tryLogin(ctx),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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