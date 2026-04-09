import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';

/// Hive-backed local cache for offline support
class HiveCacheDataSource {
  Box<dynamic> get _settings => Hive.box(HiveBoxes.settings);
  Box<dynamic> get _reservationsCache => Hive.box(HiveBoxes.reservationsCache);

  // ── Settings ─────────────────────────────────────────────────

  bool get notificationsEnabled =>
      _settings.get(SettingsKeys.notificationsEnabled, defaultValue: true) as bool;

  Future<void> setNotificationsEnabled(bool value) async {
    await _settings.put(SettingsKeys.notificationsEnabled, value);
  }

  String? get lastUserId =>
      _settings.get(SettingsKeys.lastUserId) as String?;

  Future<void> setLastUserId(String uid) async {
    await _settings.put(SettingsKeys.lastUserId, uid);
  }

  Future<void> clearLastUserId() async {
    await _settings.delete(SettingsKeys.lastUserId);
  }

  // ── Reservations Cache (offline fallback) ────────────────────

  Future<void> cacheReservations(String userId, List<Map<String, dynamic>> reservations) async {
    await _reservationsCache.put(userId, reservations);
  }

  List<Map<String, dynamic>> getCachedReservations(String userId) {
    final cached = _reservationsCache.get(userId);
    if (cached == null) return const [];
    return (cached as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
