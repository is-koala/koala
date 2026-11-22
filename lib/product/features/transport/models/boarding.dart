/// Biniş teyidi modelleri (#217). Biniş kapı değil kanıt: hiçbir bayrak binişi
/// reddetmez, sunucu yalnız işaret koyar.
library;

import 'dart:math';

/// `BOARDED` ya da işverenin `NO_SHOW` işareti.
enum BoardingKind {
  boarded('BOARDED', 'Bindi'),
  noShow('NO_SHOW', 'Binmedi');

  const BoardingKind(this.code, this.displayName);

  final String code;
  final String displayName;

  /// Tanınmayan değerde `null`; satır "henüz kayıt yok" gibi çizilir.
  static BoardingKind? fromCode(Object? value) {
    for (final kind in values) {
      if (kind.code == value) return kind;
    }
    return null;
  }
}

/// Sunucunun makullük bayrakları; kapı değil, işverene bilgi.
enum BoardingFlag {
  farFromStop('FAR_FROM_STOP', 'Durağa uzak'),
  offSchedule('OFF_SCHEDULE', 'Durak saatinden sapma'),
  staticQr('STATIC_QR', 'Basılı QR'),
  deviceTimeImplausible('DEVICE_TIME_IMPLAUSIBLE', 'Cihaz saati tutarsız'),
  lateSync('LATE_SYNC', 'Geç gönderildi');

  const BoardingFlag(this.code, this.displayName);

  final String code;
  final String displayName;

  static BoardingFlag? fromCode(Object? value) {
    for (final flag in values) {
      if (flag.code == value) return flag;
    }
    return null;
  }

  static Set<BoardingFlag> parseAll(Object? value) => value is List
      ? value.map(fromCode).nonNulls.toSet()
      : const <BoardingFlag>{};
}

/// Koltuğun o kalkıştaki durumu: BOARDED olayı, yoksa son NO_SHOW; kayıt yoksa
/// `null`.
class SeatBoardingStatus {
  const SeatBoardingStatus({required this.kind, required this.occurredAt});

  final BoardingKind kind;
  final DateTime occurredAt;

  bool get boarded => kind == BoardingKind.boarded;

  static SeatBoardingStatus? parse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final kind = BoardingKind.fromCode(value['kind']);
    final occurredAt = _parseDate(value['occurredAt']);
    if (kind == null || occurredAt == null) return null;
    return SeatBoardingStatus(kind: kind, occurredAt: occurredAt);
  }
}

class BoardingEvent {
  const BoardingEvent({
    required this.id,
    required this.kind,
    required this.occurredAt,
    this.seatAssignmentId,
    this.jobAssignmentId,
    this.shuttleId,
    this.source,
    this.capturedAt,
    this.flags = const {},
    this.replayed = false,
  });

  final String id;
  final String? seatAssignmentId;
  final String? jobAssignmentId;
  final String? shuttleId;
  final BoardingKind kind;

  /// Ekranda yalnız "işçi okuttu mu" için okunuyor.
  final String? source;
  final DateTime occurredAt;
  final DateTime? capturedAt;
  final Set<BoardingFlag> flags;

  /// `true` ise olay zaten kayıtlıydı; istemci başarı sayar.
  final bool replayed;

  bool get scannedByWorker => source == 'WORKER_SCANNED_SHUTTLE_QR';

  factory BoardingEvent.fromJson(Map<String, dynamic> json) {
    return BoardingEvent(
      id: '${json['id']}',
      seatAssignmentId: json['seatAssignmentId'] as String?,
      jobAssignmentId: json['jobAssignmentId'] as String?,
      shuttleId: json['shuttleId'] as String?,
      kind: BoardingKind.fromCode(json['kind']) ?? BoardingKind.boarded,
      source: json['source'] as String?,
      occurredAt:
          _parseDate(json['occurredAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      capturedAt: _parseDate(json['capturedAt']),
      flags: BoardingFlag.parseAll(json['flags']),
      replayed: json['replayed'] == true,
    );
  }
}

/// Sunucunun ürettiği biniş QR'ı. [token] imzalı; istemci üretmez ve
/// değiştirmez. [toString] token'ı yazmaz.
class BoardingQr {
  const BoardingQr({
    required this.token,
    required this.isStatic,
    required this.issuedAt,
    required this.uri,
    this.expiresAt,
    this.refreshAt,
  });

  final String token;

  /// Basılabilen süresiz QR; [expiresAt] ve [refreshAt] `null`.
  final bool isStatic;

  /// Yenileme cihaz saatine değil bu ana göre planlanır.
  final DateTime issuedAt;

  final DateTime? expiresAt;

  final DateTime? refreshAt;

  final String uri;

  /// Bir sonraki yenilemeye kadarki süre, sunucu saatiyle; statikte `null`.
  /// Sıfır ya da negatifse [minimumRefresh], ekran döngüye girmesin.
  Duration? get refreshDelay {
    final refresh = refreshAt;
    if (isStatic || refresh == null) return null;
    final delay = refresh.difference(issuedAt);
    return delay < minimumRefresh ? minimumRefresh : delay;
  }

  static const Duration minimumRefresh = Duration(seconds: 5);

  factory BoardingQr.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final uri = json['uri'];
    final issuedAt = _parseDate(json['issuedAt']);
    if (token is! String || token.isEmpty || uri is! String || uri.isEmpty) {
      throw const FormatException('Biniş QR yanıtı eksik.');
    }
    return BoardingQr(
      token: token,
      isStatic: json['static'] == true,
      issuedAt: issuedAt ?? DateTime.now().toUtc(),
      expiresAt: _parseDate(json['expiresAt']),
      refreshAt: _parseDate(json['refreshAt']),
      uri: uri,
    );
  }

  @override
  String toString() =>
      'BoardingQr(static: $isStatic, issuedAt: $issuedAt, '
      'refreshAt: $refreshAt)';
}

class ShuttleBoardingRow {
  const ShuttleBoardingRow({
    required this.seatAssignmentId,
    required this.stopId,
    required this.scheduledAt,
    required this.boarded,
    this.jobAssignmentId,
    this.workerId,
    this.firstName,
    this.lastName,
    this.stopLabel,
    this.event,
  });

  final String seatAssignmentId;
  final String? jobAssignmentId;
  final String? workerId;

  /// İşçi hesabını silmişse `null`; satır kalır.
  final String? firstName;
  final String? lastName;
  final String stopId;
  final String? stopLabel;

  final DateTime scheduledAt;
  final bool boarded;

  /// BOARDED, yoksa son NO_SHOW, yoksa `null` (henüz binmedi).
  final BoardingEvent? event;

  /// Sunucunun bildirim metniyle aynı dil.
  String get displayName {
    final name = [
      firstName ?? '',
      lastName ?? '',
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? 'Adı olmayan çalışan' : name;
  }

  bool get isNoShow => !boarded && event?.kind == BoardingKind.noShow;

  String get stopName {
    final label = stopLabel?.trim();
    return label == null || label.isEmpty ? 'Durak' : label;
  }

  ShuttleBoardingRow withEvent(BoardingEvent event) => ShuttleBoardingRow(
    seatAssignmentId: seatAssignmentId,
    jobAssignmentId: jobAssignmentId,
    workerId: workerId,
    firstName: firstName,
    lastName: lastName,
    stopId: stopId,
    stopLabel: stopLabel,
    scheduledAt: scheduledAt,
    boarded: event.kind == BoardingKind.boarded,
    event: event,
  );

  factory ShuttleBoardingRow.fromJson(Map<String, dynamic> json) {
    final event = json['event'];
    return ShuttleBoardingRow(
      seatAssignmentId: '${json['seatAssignmentId']}',
      jobAssignmentId: json['jobAssignmentId'] as String?,
      workerId: json['workerId'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      stopId: '${json['stopId']}',
      stopLabel: json['stopLabel'] as String?,
      scheduledAt:
          _parseDate(json['scheduledAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      boarded: json['boarded'] == true,
      event: event is Map<String, dynamic>
          ? BoardingEvent.fromJson(event)
          : null,
    );
  }
}

/// Öneki sunucu koyuyor (`BoardingTokens`).
enum BoardingTokenKind {
  /// Servisin QR'ı; işçi okutur.
  shuttle('s1'),

  /// İşçinin koltuk QR'ı; işveren okutur.
  worker('w1');

  const BoardingTokenKind(this.prefix);

  final String prefix;
}

/// Okutulan QR'dan çıkan token: `s1.{shuttleId}.…` ya da
/// `w1.{seatAssignmentId}.…`. İstemci yalnız biçimi okur (hangi uç, hangi
/// kimlik); imzayı doğrulamaz. [toString] token'ı yazmaz, QR yükü loglara
/// düşmemeli.
class BoardingToken {
  const BoardingToken._(this.kind, this.subjectId, this.value);

  final BoardingTokenKind kind;

  final String subjectId;

  final String value;

  /// Sunucunun `@Size(max = 256)` sınırı.
  static const int maxLength = 256;

  static const String linkHost = 'board';

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );
  static final RegExp _segment = RegExp(r'^[A-Za-z0-9_-]+$');

  /// Okutulan metni çözer; uymayan her şeyde `null`. Yalnız bu flavor'ın
  /// şemasıyla `{şema}://board?t=<token>` ya da çıplak token: başka flavor'ın
  /// QR'ı başka ortamın sunucusuna ait.
  static BoardingToken? parse(String raw, {required String appScheme}) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (text.contains('://')) {
      final uri = Uri.tryParse(text);
      if (uri == null ||
          uri.scheme != appScheme ||
          uri.host != linkHost ||
          uri.path.isNotEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasPort ||
          uri.fragment.isNotEmpty) {
        return null;
      }
      final values = uri.queryParametersAll['t'];
      if (values == null || values.length != 1) return null;
      return fromValue(values.single);
    }
    return fromValue(text);
  }

  static BoardingToken? fromValue(String value) {
    if (value.isEmpty || value.length > maxLength) return null;
    final parts = value.split('.');
    if (parts.length != 4) return null;
    final kind = BoardingTokenKind.values
        .where((kind) => kind.prefix == parts[0])
        .firstOrNull;
    if (kind == null || !_uuid.hasMatch(parts[1])) return null;
    if (!_segment.hasMatch(parts[2]) || !_segment.hasMatch(parts[3])) {
      return null;
    }
    return BoardingToken._(kind, parts[1].toLowerCase(), value);
  }

  @override
  String toString() => 'BoardingToken(${kind.prefix})';
}

/// Son bilinen konum yalnız bundan gençse eklenir; eskisi "durağa uzak"
/// bayrağını yanlış üretir.
const Duration boardingLocationMaxAge = Duration(minutes: 2);

/// Rastgele UUID v4; aynı kimlikle yeniden deneme güvenli (`replayed`).
String newBoardingClientEventId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
