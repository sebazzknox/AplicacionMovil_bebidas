import 'package:flutter/material.dart';

class AdminConsolePage extends StatelessWidget {
  const AdminConsolePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(leading: Icon(Icons.checklist), title: Text('Aprobaciones de stock')),
          ListTile(leading: Icon(Icons.attach_money), title: Text('Finanzas')),
          ListTile(leading: Icon(Icons.insights), title: Text('Reportes')),
        ],
      ),
    );
  }
}