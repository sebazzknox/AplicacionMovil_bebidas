import 'package:flutter/material.dart';
import 'comercios_page.dart';

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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Buscador "dummy" → abre la lista con foco
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

                  // Acciones principales
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
                    subtitle: 'Promos destacadas (próximamente)',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Próximamente ✨')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.map_outlined,
                    title: 'Mapa',
                    subtitle: 'Ver comercios en el mapa (próximamente)',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Próximamente ✨')),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
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

  // Sheet con login simple de admin (PIN) – luego lo cambiamos por Firebase Auth
  void _showAdminLogin(BuildContext context) {
    final pinCtrl = TextEditingController();

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
                subtitle: Text('Ingresá tu PIN para gestionar bebidas'),
              ),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
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
                    onPressed: () {
                      // ⚠️ PIN provisorio: cambiamos luego por Firebase Auth
                      const pinValido = '1234';
                      if (pinCtrl.text.trim() == pinValido) {
                        Navigator.pop(ctx); // cerramos el sheet
                        // Marcamos admin via argumento de ruta o provider simple
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ComerciosPage(), // abre lista
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Modo admin activado')),
                        );
                      } else {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('PIN incorrecto')),
                        );
                      }
                    },
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