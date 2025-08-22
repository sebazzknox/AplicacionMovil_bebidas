import 'package:flutter/material.dart';
import 'comercios_page.dart';
import 'ofertas_page.dart';

class CustomerHomePage extends StatelessWidget {
  const CustomerHomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DESCABIO')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.store_outlined),
            title: const Text('Explorar comercios'),
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ComerciosPage())),
          ),
          ListTile(
            leading: const Icon(Icons.local_offer_outlined),
            title: const Text('Ofertas'),
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const OfertasPage())),
          ),
        ],
      ),
    );
  }
}