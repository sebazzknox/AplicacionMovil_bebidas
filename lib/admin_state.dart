import 'package:flutter/widgets.dart';

/// Notifier global para el modo admin
final ValueNotifier<bool> adminMode = ValueNotifier<bool>(false);

/// InheritedNotifier que propaga el estado de admin
class AdminState extends InheritedNotifier<ValueNotifier<bool>> {
  // 🔧 NO const: el super recibe un notifier que no es constante
  AdminState({super.key, required Widget child})
      : super(notifier: adminMode, child: child);

  /// true/false si es admin (sin usar ValueListenableBuilder)
  static bool isAdmin(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminState>()
              ?.notifier
              ?.value ??
      adminMode.value;

  /// Acceso al notifier para escuchar o cambiar el valor
  static ValueNotifier<bool> listenable(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminState>()?.notifier ??
      adminMode;
}