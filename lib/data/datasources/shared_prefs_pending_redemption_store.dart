import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/pending_redemption.dart';
import '../../domain/repositories/stamp_repository.dart';

/// Guarda los escaneos pendientes en el almacenamiento privado de la app,
/// separados por usuario. El token QR es temporal (≈60 s), está firmado por el
/// servidor y solo sirve junto con la sesión del propio usuario, por lo que no
/// requiere cifrado adicional.
class SharedPrefsPendingRedemptionStore implements PendingRedemptionStore {
  SharedPrefsPendingRedemptionStore({SharedPreferencesAsync? prefs}) : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  String _key(String uid) => 'pending_redemptions_$uid';

  @override
  Future<List<PendingRedemption>> load(String uid) async {
    try {
      final raw = await _prefs.getString(_key(uid));
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map(PendingRedemption.tryFromJson).whereType<PendingRedemption>().toList();
    } catch (error) {
      debugPrint('No se pudieron leer los escaneos pendientes: $error');
      return [];
    }
  }

  @override
  Future<void> save(String uid, List<PendingRedemption> items) async {
    if (items.isEmpty) {
      await _prefs.remove(_key(uid));
      return;
    }
    await _prefs.setString(_key(uid), jsonEncode([for (final item in items) item.toJson()]));
  }
}
