import 'package:flutter/foundation.dart';

/// Estado global MUY simple para el “modo admin”.
final ValueNotifier<bool> adminMode = ValueNotifier<bool>(false);