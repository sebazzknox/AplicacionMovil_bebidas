import 'package:flutter/material.dart';

class MerchantConsolePage extends StatelessWidget {
  const MerchantConsolePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comerciante')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(leading: Icon(Icons.inventory_2_outlined), title: Text('Inventario')),
          ListTile(leading: Icon(Icons.add_circle_outline), title: Text('Nuevo movimiento')),
          ListTile(leading: Icon(Icons.campaign_outlined), title: Text('Notificaciones a clientes (cuando esté aprobado)')),
        ],
      ),
    );
  }
}