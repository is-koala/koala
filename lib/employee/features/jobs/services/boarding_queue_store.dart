import 'dart:convert';

import 'package:koala/employee/features/jobs/models/pending_boarding.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bekleyen biniş okutmalarının saklama seam'i (is-koala/koala#217).
abstract interface class BoardingQueueStore {
  /// Tüm kullanıcıların kayıtları, eklenme sırasıyla.
  Future<List<PendingBoarding>> readAll();

  Future<void> writeAll(List<PendingBoarding> entries);

  Future<String?> readLastActiveUser();

  Future<void> setLastActiveUser(String? userId);
}

/// `SharedPreferences` üzerinde JSON liste.
///
/// Kayıtlar az (günde yön başına en fazla bir okutma) ve kısa ömürlü;
/// mesai kuyruğunun SQLite deposu kadar ağır bir yapıya gerek yok.
class SharedPreferencesBoardingQueueStore implements BoardingQueueStore {
  const SharedPreferencesBoardingQueueStore();

  static const String _entriesKey = 'boarding_queue_entries_v1';
  static const String _activeUserKey = 'boarding_queue_active_user_v1';

  @override
  Future<List<PendingBoarding>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map(PendingBoarding.fromJson).nonNulls.toList();
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> writeAll(List<PendingBoarding> entries) async {
    final prefs = await SharedPreferences.getInstance();
    if (entries.isEmpty) {
      await prefs.remove(_entriesKey);
      return;
    }
    await prefs.setString(
      _entriesKey,
      jsonEncode([for (final entry in entries) entry.toJson()]),
    );
  }

  @override
  Future<String?> readLastActiveUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeUserKey);
  }

  @override
  Future<void> setLastActiveUser(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId == null) {
      await prefs.remove(_activeUserKey);
    } else {
      await prefs.setString(_activeUserKey, userId);
    }
  }
}

/// Okutmayı sunucuya taşıyan seam.
abstract interface class BoardingGateway {
  Future<BoardingEvent> send(PendingBoarding entry);
}

/// `POST /shuttles/{shuttleId}/boardings`.
class TransportBoardingGateway implements BoardingGateway {
  TransportBoardingGateway({TransportService? service})
    : _service = service ?? TransportService();

  final TransportService _service;

  @override
  Future<BoardingEvent> send(PendingBoarding entry) {
    return _service.boardOnShuttle(
      entry.shuttleId,
      token: entry.token,
      capturedAt: entry.capturedAt,
      clientEventId: entry.clientEventId,
      latitude: entry.latitude,
      longitude: entry.longitude,
    );
  }
}
