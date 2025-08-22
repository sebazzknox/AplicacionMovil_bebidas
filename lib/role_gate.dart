import 'package:flutter/material.dart';
import 'user_role.dart';

class RoleGate extends StatelessWidget {
  final AppRole role;
  final Widget admin;
  final Widget merchant;
  final Widget customer;
  final Widget loading;

  const RoleGate({
    super.key,
    required this.role,
    required this.admin,
    required this.merchant,
    required this.customer,
    this.loading = const Center(child: CircularProgressIndicator()),
  });

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case AppRole.admin: return admin;
      case AppRole.merchant: return merchant;
      case AppRole.customer: return customer;
      case AppRole.unknown: default: return loading;
    }
  }
}