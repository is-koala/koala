import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Aynı `notificationId`'nin ikinci teslimatını yutar.
///
/// Backend aynı olayı yeniden gönderebiliyor. Kayıt diskte durur çünkü
/// süreç öldükten sonra gelen kopya da işlenmemeli; yedi gün sonra silinir
/// çünkü sonsuz bir harita birikmesin.
class PushNotificationDedupe {
  PushNotificationDedupe({
    SharedPreferences? prefs,
    DateTime Function()? now,
    this.ttl = const Duration(days: 7),
  }) : _prefs = prefs,
       _now = now ?? DateTime.now;

  static const String storageKey = 'push_handled_notifications';

  final SharedPreferences? _prefs;
  final DateTime Function() _now;
  final Duration ttl;

  /// İlk kez görülürse `true`; kopya ya da süresi dolmamış kayıtta `false`.
  Future<bool> claim(String notificationId) async {
    if (notificationId.isEmpty) return false;

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final records = _read(prefs);
    final now = _now().toUtc();
    records.removeWhere((_, stampedAt) => now.difference(stampedAt) >= ttl);

    final existing = records[notificationId];
    if (existing != null && now.difference(existing) < ttl) {
      await _write(prefs, records);
      return false;
    }

    records[notificationId] = now;
    await _write(prefs, records);
    return true;
  }

  Map<String, DateTime> _read(SharedPreferences prefs) {
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};

    final records = <String, DateTime>{};
    for (final entry in decoded.entries) {
      final millis = entry.value;
      if (millis is! num) continue;
      records[entry.key.toString()] = DateTime.fromMillisecondsSinceEpoch(
        millis.toInt(),
        isUtc: true,
      );
    }
    return records;
  }

  Future<void> _write(SharedPreferences prefs, Map<String, DateTime> records) {
    final payload = {
      for (final entry in records.entries)
        entry.key: entry.value.toUtc().millisecondsSinceEpoch,
    };
    return prefs.setString(storageKey, jsonEncode(payload));
  }
}
