import 'package:flutter/foundation.dart';

/// Estado global del modo admin (para todas las pantallas)
final ValueNotifier<bool> adminMode = ValueNotifier<bool>(false);

/// Flag global simple (si querés usarla en checks rápidos)
bool kIsAdmin = false;