// lib/zonas_entrega_admin.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ZonasEntregaAdmin extends StatefulWidget {
  final String comercioId;
  final String? comercioNombre; // opcional para mostrar en el título

  const ZonasEntregaAdmin({
    super.key,
    required this.comercioId,
    this.comercioNombre,
  });

  @override
  State<ZonasEntregaAdmin> createState() => _ZonasEntregaAdminState();
}

class _ZonasEntregaAdminState extends State<ZonasEntregaAdmin> {
  // Zonas fijas (lo que pidió el cliente)
  static const _opciones = <String>['Claypole', 'Solano'];

  // Para UI optimista (se combinan con lo que viene de Firestore)
  final Set<String> _localActivas = {};

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('comercios')
          .doc(widget.comercioId)
          .collection('zonas_entrega');

  @override
  Widget build(BuildContext context) {
    final titulo = (widget.comercioNombre == null || widget.comercioNombre!.isEmpty)
        ? 'Zonas de entrega'
        : 'Zonas de entrega · ${widget.comercioNombre}';

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.snapshots(),
        builder: (context, snap) {
          // Carga inicial
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Activas que vienen de Firestore
          final remotasActivas = <String>{};
          if (snap.hasData) {
            for (final d in snap.data!.docs) {
              final data = d.data();
              final nombre = (data['nombre'] ?? '') as String;
              final activo = (data['activo'] ?? false) == true;
              if (activo) remotasActivas.add(nombre);
            }
          }

          // Unimos remotas + cambios locales (UI optimista)
          final visibles = {...remotasActivas, ..._localActivas};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Activá las zonas donde el comercio entrega pedidos:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _opciones.map((zona) {
                  final isOn = visibles.contains(zona);
                  return FilterChip(
                    label: Text(zona),
                    selected: isOn,
                    onSelected: (val) async {
                      // UI optimista
                      setState(() {
                        if (val) {
                          _localActivas.add(zona);
                        } else {
                          _localActivas.remove(zona);
                        }
                      });
                      await _toggleZona(zona, val);
                      // El snapshot sincroniza el estado definitivo
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),

              Text('Resumen', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                visibles.isEmpty
                    ? 'Sin zonas activas'
                    : 'Activas: ${visibles.join(", ")}',
              ),
            ],
          );
        },
      ),
    );
  }

  /// Guarda el estado de una zona y mantiene en el doc del comercio
  /// un array denormalizado `zonasEntrega` para mostrar rápido en listas.
  Future<void> _toggleZona(String nombre, bool activar) async {
    final refZona = _col.doc(nombre);
    final refComercio = FirebaseFirestore.instance
        .collection('comercios')
        .doc(widget.comercioId);

    try {
      // 1) Guardar/actualizar subdoc
      await refZona.set(
        {
          'nombre': nombre,
          'activo': activar,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 2) Mantener array en el doc del comercio
      await refComercio.set(
        {
          'zonasEntrega': activar
              ? FieldValue.arrayUnion([nombre])
              : FieldValue.arrayRemove([nombre]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activar ? 'Zona "$nombre" activada' : 'Zona "$nombre" desactivada',
            ),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      }
    } catch (e) {
      // Revertimos cambio local si falló
      setState(() {
        if (activar) {
          _localActivas.remove(nombre);
        } else {
          _localActivas.add(nombre);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la zona: $e')),
        );
      }
    }
  }
}