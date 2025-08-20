import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ComercioDetallePage extends StatelessWidget {
  const ComercioDetallePage({super.key, required this.comercioId});

  final String comercioId;

  @override
  Widget build(BuildContext context) {
    final docRef =
        FirebaseFirestore.instance.collection('comercios').doc(comercioId);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del comercio')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Comercio no encontrado.'));
          }

          final data = snap.data!.data()!;
          final nombre = (data['nombre'] ?? '') as String;
          final ciudad = (data['ciudad'] ?? '') as String?;
          final provincia = (data['provincia'] ?? '') as String?;
          final fotoUrl = data['fotoUrl'] as String?;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (fotoUrl != null && fotoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(fotoUrl, height: 180, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront, size: 48),
                ),
              const SizedBox(height: 16),
              Text(
                nombre,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if ((ciudad ?? '').isNotEmpty || (provincia ?? '').isNotEmpty)
                Text(
                  [ciudad, provincia].where((e) => (e ?? '').isNotEmpty).join(' • '),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 24),
              const Text(
                'Aquí después mostramos: contactos, redes, horario, mapa, etc.',
              ),
            ],
          );
        },
      ),
    );
  }
}
