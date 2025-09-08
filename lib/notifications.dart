// lib/notifications.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Notifications {
  Notifications._();
  static final FirebaseMessaging _msg = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'ofertas', // debe coincidir con Manifest
    'Ofertas',
    description: 'Notificaciones de nuevas ofertas',
    importance: Importance.high,
  );

  static Future<void> init() async {
    // local notifications
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initIOS = DarwinInitializationSettings();
    const init = InitializationSettings(android: initAndroid, iOS: initIOS);
    await _fln.initialize(init);

    // canal android
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // notificaciones en 1er plano => mostrar local
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null) return;
      _fln.show(
        n.hashCode,
        n.title ?? 'Nueva oferta',
        n.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });
  }

  static Future<bool> _ensurePermission() async {
    final s = await _msg.requestPermission(alert: true, badge: true, sound: true);
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Guarda el token en /users/{uid}/tokens/{token}
  static Future<void> _saveToken(String uid) async {
    final t = await _msg.getToken();
    if (t == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tokens')
        .doc(t)
        .set({
      'createdAt': FieldValue.serverTimestamp(),
      'platform': Platform.operatingSystem,
    }, SetOptions(merge: true));
  }

  /// Activa/desactiva y persiste en /users/{uid}.notifOfertas
  static Future<void> setEnabled(String uid, bool enabled) async {
    if (enabled) {
      final ok = await _ensurePermission();
      if (!ok) {
        throw Exception('Permiso de notificaciones denegado.');
      }
      await _msg.subscribeToTopic('ofertas');
      await _saveToken(uid);
    } else {
      await _msg.unsubscribeFromTopic('ofertas');
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'notifOfertas': enabled}, SetOptions(merge: true));
  }

  static Stream<bool> enabledStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) => (s.data()?['notifOfertas'] == true));
  }

  /// Aviso inmediato para confirmar la activación
  static Future<void> showTest() async {
    await _fln.show(
      0,
      'Nueva oferta',
      'Hay una nueva oferta 🤩',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}