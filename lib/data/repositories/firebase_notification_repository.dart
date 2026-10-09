import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/notification_repository.dart';

/// Registra el token FCM del dispositivo en `user_passport/{uid}/fcm_tokens`.
/// Un trigger del servidor lo suscribe a los temas según las preferencias.
class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository(this._messaging, this._db, {SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _enabledKey = 'notifications_enabled_on_device';

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  final SharedPreferencesAsync _prefs;

  @override
  bool get isSupported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  String get _platform => kIsWeb
      ? 'web'
      : defaultTargetPlatform == TargetPlatform.iOS
      ? 'ios'
      : 'android';

  @override
  Future<bool> enableOnThisDevice(String uid) async {
    if (!isSupported) return false;
    try {
      final settings = await _messaging.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return false;
      await _register(uid);
      await _prefs.setBool(_enabledKey, true);
      return true;
    } catch (error) {
      debugPrint('No se pudieron activar las notificaciones: $error');
      return false;
    }
  }

  @override
  Future<void> refreshRegistration(String uid) async {
    if (!isSupported || !await isEnabledOnThisDevice()) return;
    try {
      await _register(uid);
    } catch (error) {
      debugPrint('No se pudo actualizar el token de notificaciones: $error');
    }
  }

  Future<void> _register(String uid) async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _tokenDoc(uid, token).set({'token': token, 'platform': _platform, 'updatedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> disableOnThisDevice(String uid) async {
    if (!isSupported) return;
    await _prefs.setBool(_enabledKey, false);
    try {
      final token = await _messaging.getToken();
      if (token != null) await _tokenDoc(uid, token).delete();
      await _messaging.deleteToken();
    } catch (error) {
      debugPrint('No se pudo desactivar el token de notificaciones: $error');
    }
  }

  @override
  Future<bool> isEnabledOnThisDevice() async {
    if (!isSupported) return false;
    try {
      if (await _prefs.getBool(_enabledKey) != true) return false;
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<InAppNotification> get foregroundMessages => FirebaseMessaging.onMessage
      .where((m) => m.notification != null)
      .map((m) => InAppNotification(title: m.notification!.title ?? 'Aviso', body: m.notification!.body ?? ''));

  DocumentReference<Map<String, dynamic>> _tokenDoc(String uid, String token) =>
      _db.collection('user_passport').doc(uid).collection('fcm_tokens').doc(token);
}
