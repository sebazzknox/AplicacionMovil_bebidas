// lib/admin_panel_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'comercios_page.dart';
import 'ofertas_page.dart';
import 'stock_page.dart';
import 'finanzas_page.dart';

class AdminPanelPage extends StatelessWidget {
  const AdminPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de administración'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: adminMode,
            builder: (_, isOn, __) => IconButton(
              tooltip: isOn ? 'Salir de admin' : 'Entrar a admin',
              icon: Icon(isOn ? Icons.lock_open : Icons.lock_outline),
              onPressed: () {
                adminMode.value = !isOn;
                // sincronizamos con kIsAdmin usado en otras pantallas
                // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
                // (kIsAdmin es const en tu file original; si lo hiciste mutable, se actualiza)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isOn
                        ? 'Modo admin desactivado'
                        : 'Modo admin activado'),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          const SizedBox(height: 8),
          // Avizo de estado admin
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ValueListenableBuilder<bool>(
              valueListenable: adminMode,
              builder: (_, isOn, __) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isOn ? Colors.green : Colors.orange)
                      .withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOn ? Icons.verified_user : Icons.info_outline,
                      color: isOn ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isOn
                            ? 'Estás en modo administrador.'
                            : 'No estás en modo administrador. Algunas acciones estarán deshabilitadas.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _AdminTile(
                  icon: Icons.store_mall_directory_outlined,
                  title: 'Comercios',
                  subtitle: 'Listado y edición',
                  enabled: kIsAdmin,
                  onTap: (ctx) => Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => const ComerciosPage()),
                  ),
                ),
                _AdminTile(
                  icon: Icons.local_offer_outlined,
                  title: 'Ofertas',
                  subtitle: 'Promos destacadas',
                  enabled: kIsAdmin,
                  onTap: (ctx) => Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => const OfertasPage()),
                  ),
                ),
                _AdminTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Stock',
                  subtitle: 'Por comercio',
                  enabled: kIsAdmin,
                  onTap: (ctx) async {
                    final picked = await _pickComercio(ctx);
                    if (picked == null) return;
                    // navego al stock del comercio elegido
                    // ignore: use_build_context_synchronously
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => StockPage(
                          comercioId: picked['id']!,
                          comercioNombre: picked['nombre']!,
                        ),
                      ),
                    );
                  },
                ),
                _AdminTile(
                  icon: Icons.payments_outlined,
                  title: 'Finanzas',
                  subtitle: 'Ingresos y gastos',
                  enabled: kIsAdmin,
                  onTap: (ctx) => Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => const FinanzasPage()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: kIsAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showQuickActions(context),
              icon: const Icon(Icons.flash_on_outlined),
              label: const Text('Accesos rápidos'),
            )
          : null,
    );
  }

  // ---------- Accesos rápidos opcionales ----------
  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Accesos rápidos')),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Ver Comercios'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ComerciosPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_offer_outlined),
              title: const Text('Ver Ofertas'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OfertasPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Selector de comercio para el módulo Stock ----------
  Future<Map<String, String>?> _pickComercio(BuildContext parentCtx) async {
    return await showModalBottomSheet<Map<String, String>>(
      context: parentCtx,
      isScrollControlled: true,
      builder: (ctx) {
        final col = FirebaseFirestore.instance.collection('comercios');
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.store_mall_directory),
                  title: Text('Elegir comercio'),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: col.orderBy('nombre').snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(child: Text('No hay comercios.'));
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final d = docs[i];
                          final data = d.data();
                          final nombre = (data['nombre'] ?? '') as String;
                          final ciudad = (data['ciudad'] ?? '') as String?;
                          final provincia = (data['provincia'] ?? '') as String?;
                          final subt = [
                            if (ciudad != null && ciudad.isNotEmpty) ciudad,
                            if (provincia != null && provincia.isNotEmpty) provincia,
                          ].join(' • ');
                          return ListTile(
                            leading: const Icon(Icons.storefront),
                            title: Text(nombre),
                            subtitle: subt.isEmpty ? null : Text(subt),
                            onTap: () => Navigator.pop(ctx, {
                              'id': d.id,
                              'nombre': nombre,
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final void Function(BuildContext) onTap;

  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final card = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? () => onTap(context) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withOpacity(.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor:
                  (enabled ? cs.primaryContainer : cs.surfaceContainerHighest),
              child: Icon(
                icon,
                color: enabled ? cs.onPrimaryContainer : cs.outline,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: enabled ? null : cs.outline,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: enabled ? cs.onSurfaceVariant : cs.outlineVariant,
                  ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.chevron_right,
                color: enabled ? cs.primary : cs.outlineVariant,
              ),
            )
          ],
        ),
      ),
    );

    return card;
  }
}