// lib/credenciales/credenciales_admin_page.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../admin_state.dart';

class CredencialesAdminPage extends StatefulWidget {
  const CredencialesAdminPage({super.key});

  @override
  State<CredencialesAdminPage> createState() => _CredencialesAdminPageState();
}

class _CredencialesAdminPageState extends State<CredencialesAdminPage> {
  @override
  Widget build(BuildContext context) {
    if (!AdminState.isAdmin(context)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Credenciales')),
        body: const Center(child: Text('Sólo para administradores')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Credenciales · Admin')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _emitirSinSolicitud,
        // ← único cambio: icono compatible
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Emitir sin solicitud'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text('Solicitudes pendientes',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _SolicitudesList(
            onEmitir: _emitirCredencial,
            onRechazar: _rechazarSolicitud,
          ),
          const SizedBox(height: 16),
          Text('Credenciales emitidas',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _EmitidasList(onGestionar: _gestionarCredencial),
        ],
      ),
    );
  }

  /* =================== acciones sobre SOLICITUDES =================== */

  Future<void> _rechazarSolicitud(
      DocumentSnapshot<Map<String, dynamic>> req) async {
    final motivo = await _pedirMotivo(context);
    if (motivo == null) return;
    await req.reference.update({
      'estado': 'rechazada',
      'status': 'rechazada',
      'motivo': motivo,
      'processedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Solicitud rechazada')));
    }
  }

  /* =================== EMITIR CREDENCIAL =================== */

  Future<void> _emitirCredencial(String uid) async {
    final cs = Theme.of(context).colorScheme;

    String tier = 'CLASICA';
    DateTime exp = DateTime.now().add(const Duration(days: 365));

    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              final niveles = ['CLASICA', 'PLUS', 'PREMIUM'];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    leading: Icon(Icons.badge_outlined),
                    title: Text('Emitir credencial'),
                    subtitle: Text('Elegí categoría y vencimiento'),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: niveles.map((t) {
                      final sel = (t == tier);
                      return ChoiceChip(
                        label: Text(t),
                        selected: sel,
                        selectedColor: cs.primaryContainer.withOpacity(.6),
                        onSelected: (_) => setLocal(() => tier = t),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(
                      'Vence: ${exp.day.toString().padLeft(2, '0')}/${exp.month.toString().padLeft(2, '0')}/${exp.year}',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: exp,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) setLocal(() => exp = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Emitir'),
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    if (ok != true) return;

    final numero = _generarNumero();
    final nonce = _rand(10);

    await FirebaseFirestore.instance.collection('credenciales').doc(uid).set({
      'uid': uid,
      'numero': numero,
      'tier': tier,
      'estado': 'activa',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expira': Timestamp.fromDate(DateTime(exp.year, exp.month, exp.day, 23, 59)),
      'qrValue': 'descabio|$uid|$tier|$nonce',
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credencial emitida para UID $uid ($tier)')),
      );
    }
  }

  /* ======= GESTIONAR credencial emitida (suspender/reactivar/renovar) ======= */

  Future<void> _gestionarCredencial(
      DocumentSnapshot<Map<String, dynamic>> d) async {
    final data = d.data() ?? {};
    final estado = (data['estado'] ?? 'activa').toString();

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.build_outlined),
                title: Text('Gestionar credencial'),
              ),
              if (estado != 'suspendida')
                ListTile(
                  leading: const Icon(Icons.pause_circle_outline),
                  title: const Text('Suspender credencial'),
                  textColor: cs.error,
                  iconColor: cs.error,
                  onTap: () => Navigator.pop(ctx, 'suspender'),
                ),
              if (estado == 'suspendida')
                ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: const Text('Reactivar credencial'),
                  onTap: () => Navigator.pop(ctx, 'reactivar'),
                ),
              ListTile(
                leading: const Icon(Icons.autorenew),
                title: const Text('Renovar número'),
                onTap: () => Navigator.pop(ctx, 'renovar'),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );

    if (action == null) return;

    if (action == 'suspender') {
      await d.reference.update({
        'estado': 'suspendida',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (action == 'reactivar') {
      await d.reference.update({
        'estado': 'activa',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (action == 'renovar') {
      await d.reference.update({
        'numero': _generarNumero(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /* ========== EMITIR SIN SOLICITUD (buscar por email o ingresar UID) ========== */

  Future<void> _emitirSinSolicitud() async {
    final emailCtrl = TextEditingController();
    final uidCtrl = TextEditingController();
    QuerySnapshot<Map<String, dynamic>>? resultados;
    String? selectedUid;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              Future<void> buscarPorEmail() async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty) return;
                resultados = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: email)
                    .limit(10)
                    .get();
                setLocal(() {});
              }

              Future<void> validarUID() async {
                final uid = uidCtrl.text.trim();
                if (uid.isEmpty) return;
                final doc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get();
                if (doc.exists) {
                  selectedUid = uid;
                  setLocal(() {});
                } else {
                  selectedUid = null;
                  setLocal(() {});
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('UID no encontrado en /users')),
                    );
                  }
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    leading: Icon(Icons.person_search_outlined),
                    title: Text('Emitir a un usuario'),
                    subtitle: Text('Buscá por email o ingresá el UID'),
                  ),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Buscar por email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: buscarPorEmail,
                      ),
                    ),
                    onSubmitted: (_) => buscarPorEmail(),
                  ),
                  const SizedBox(height: 8),
                  if (resultados != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: Card(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: resultados!.docs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = resultados!.docs[i];
                            final m = r.data();
                            final name = (m['displayName'] ?? '').toString();
                            final email = (m['email'] ?? '').toString();
                            return ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(name.isEmpty ? '(Sin nombre)' : name),
                              subtitle: Text(email.isEmpty ? r.id : email),
                              onTap: () {
                                selectedUid = r.id;
                                Navigator.pop(ctx, true);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: uidCtrl,
                    decoration: InputDecoration(
                      labelText: 'O ingresar UID manualmente',
                      prefixIcon: const Icon(Icons.fingerprint_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: validarUID,
                      ),
                    ),
                    onSubmitted: (_) => validarUID(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Continuar'),
                          onPressed: () {
                            if (selectedUid == null &&
                                resultados != null &&
                                resultados!.docs.isNotEmpty) {
                              selectedUid = resultados!.docs.first.id;
                            }
                            Navigator.pop(ctx, selectedUid != null);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    if (ok == true && selectedUid != null) {
      await _emitirCredencial(selectedUid!);
    }
  }

  /* =================== helpers =================== */

  Future<String?> _pedirMotivo(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Motivo del rechazo'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Opcional'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Aceptar')),
        ],
      ),
    );
  }

  String _generarNumero() {
    final rnd = Random();
    final n = 100000 + rnd.nextInt(900000);
    return 'DC-${n.toString().padLeft(6, '0')}';
  }

  String _rand(int n) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(n, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}

/* =================== widgets auxiliares =================== */

class _SolicitudesList extends StatelessWidget {
  const _SolicitudesList({
    required this.onEmitir,
    required this.onRechazar,
  });

  final Future<void> Function(String uid) onEmitir;
  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>> req)
      onRechazar;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('solicitudes_credenciales')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _CardPlaceholder();
        }
        final all = snap.data?.docs ?? [];
        final docs = all.where((d) {
          final m = d.data();
          final s = (m['estado'] ?? m['status'] ?? '').toString();
          return s.isEmpty || s == 'pendiente';
        }).toList();

        if (docs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No hay solicitudes pendientes',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final doc in docs)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                      (doc['displayName'] ?? '(Sin nombre)').toString()),
                  subtitle:
                      Text((doc['email'] ?? doc['uid'] ?? '—').toString()),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Rechazar',
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => onRechazar(doc),
                      ),
                      IconButton(
                        tooltip: 'Emitir',
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => onEmitir((doc['uid'] ?? '').toString()),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EmitidasList extends StatelessWidget {
  const _EmitidasList({required this.onGestionar});

  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>> d)
      onGestionar;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('credenciales')
          .orderBy('updatedAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _CardPlaceholder();
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Aún no hay credenciales emitidas',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final d in docs)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text((d['numero'] ?? '—').toString()),
                  subtitle: Text(
                    'UID: ${d.id}  ·  ${d['tier'] ?? '—'}  ·  ${d['estado'] ?? '—'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.more_horiz),
                    label: const Text('Gestionar'),
                    onPressed: () => onGestionar(d),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(width: 12),
            Text('Cargando…', style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}