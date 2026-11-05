/// Biniş teyidi modelleri (is-koala/koala#217, koala-backend#298 / #335).
///
/// Biniş bir kapı değil, kanıttır: işçi servisteki QR'ı okutur ya da işveren
/// işçinin QR'ını okutur / listeden işaretler. Hiçbir bayrak binişi
/// reddetmez; sunucu yalnız işaret koyar.
library;

import 'dart:math';

/// Olayın türü. Backend `BoardingKind`: `BOARDED` ya da işverenin
/// `NO_SHOW` işareti.
enum BoardingKind {
  boarded('BOARDED', 'Bindi'),
  noShow('NO_SHOW', 'Binmedi');

  const BoardingKind(this.code, this.displayName);

  final String code;
  final String displayName;

  /// Tanınmayan değerde `null`: sunucu yeni bir tür eklerse uygulama
  /// çökmemeli, satır "henüz kayıt yok" gibi çizilir.
  static BoardingKind? fromCode(Object? value) {
    for (final kind in values) {
      if (kind.code == value) return kind;
    }
    return null;
  }
}

/// Sunucunun makullük bayrakları (`TimesheetPlausibilityFlag` alt kümesi).
/// Kapı değildir; işverenin listesinde bilgi olarak yazılır.
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

  /// Bilinmeyen bayrak sessizce atlanır.
  static Set<BoardingFlag> parseAll(Object? value) => value is List
      ? value.map(fromCode).nonNulls.toSet()
      : const <BoardingFlag>{};
}

/// Koltuğun o kalkıştaki biniş durumu (`SeatBoardingStatusDto`): BOARDED
/// olayı, yoksa son NO_SHOW işareti. Kayıt yoksa sunucu `null` gönderir.
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

/// Kaydedilmiş biniş olayı (`BoardingEventDto`).
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

  /// `WORKER_SCANNED_SHUTTLE_QR`, `EMPLOYER_SCANNED_WORKER_QR` ya da
  /// `EMPLOYER_MARKED`. Ekranda yalnız işçi okuttu mu sorusu için okunuyor.
  final String? source;
  final DateTime occurredAt;
  final DateTime? capturedAt;
  final Set<BoardingFlag> flags;

  /// Yalnız POST yanıtında anlamlı: `true` ise olay zaten kayıtlıydı ve
  /// yanıt kayıtlı olaydır. İstemci bunu başarı sayar.
  final bool replayed;

  /// Olayı işçinin kendisi okutarak mı yazdı.
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

/// Sunucunun ürettiği biniş QR'ı (`BoardingQrDto`).
///
/// [token] imzalı bir HMAC token'ı; istemci onu **üretmez ve değiştirmez**,
/// QR'a sunucunun verdiği [uri] basılır. Token loglanmaz: [toString] içeriği
/// yazmaz.
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

  /// Kâğıda basılabilen süresiz servis QR'ı; [expiresAt] ve [refreshAt]
  /// `null`.
  final bool isStatic;

  /// Sunucunun basım anı. Yenileme cihaz saatine değil bu ana göre
  /// planlanır (cihaz saat farkı düşülür).
  final DateTime issuedAt;

  /// Sunucu saatiyle kabulün son anı.
  final DateTime? expiresAt;

  /// Ekrandaki QR'ın yenilenmesi gereken an.
  final DateTime? refreshAt;

  /// QR'a basılacak bağlantı: `{appScheme}://board?t=<token>`.
  final String uri;

  /// QR'ın bir sonraki yenilemeye kadar ekranda kalacağı süre, sunucu
  /// saatiyle (`refreshAt - issuedAt`). Statik QR'da `null`.
  ///
  /// Cihaz saatinden bağımsız: yanıtın geldiği andan bu kadar sonra yeni
  /// QR istenir. Sıfır ya da negatifse (sunucu pencere sınırında bastı)
  /// [minimumRefresh] kullanılır ki ekran döngüye girmesin.
  Duration? get refreshDelay {
    final refresh = refreshAt;
    if (isStatic || refresh == null) return null;
    final delay = refresh.difference(issuedAt);
    return delay < minimumRefresh ? minimumRefresh : delay;
  }

  /// İki yenileme arasındaki en kısa süre.
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

/// İşverenin biniş listesindeki bir koltuk (`ShuttleBoardingRowDto`).
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

  /// İşçi hesabını silmişse `null`; satır yine kalır.
  final String? firstName;
  final String? lastName;
  final String stopId;
  final String? stopLabel;

  /// Durağın kalkış anı (UTC).
  final DateTime scheduledAt;
  final bool boarded;

  /// Satırın durumunu belirleyen olay: BOARDED, yoksa son NO_SHOW, yoksa
  /// `null` (henüz binmedi).
  final BoardingEvent? event;

  /// Hesabını silmiş işçi "Adı olmayan çalışan" olarak yazılır — sunucunun
  /// bildirim metniyle aynı dil.
  String get displayName {
    final name = [
      firstName ?? '',
      lastName ?? '',
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? 'Adı olmayan çalışan' : name;
  }

  bool get isNoShow => !boarded && event?.kind == BoardingKind.noShow;

  /// Durak başlığı: etiket, yoksa "Durak".
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

/// Biniş token'ının türü: öneki sunucu koyuyor (`BoardingTokens`).
enum BoardingTokenKind {
  /// `s1.` — servisin QR'ı; işçi okutur.
  shuttle('s1'),

  /// `w1.` — işçinin koltuk QR'ı; işveren okutur.
  worker('w1');

  const BoardingTokenKind(this.prefix);

  final String prefix;
}

/// Okutulan QR'dan çıkan biniş token'ı.
///
/// Sunucu sözleşmesi: `s1.{shuttleId}.{pencere|static}.{mac}` ve
/// `w1.{seatAssignmentId}.{pencere}.{mac}`; QR'da
/// `{appScheme}://board?t=<token>` bağlantısı durur. İstemci yalnız biçimi
/// okur — hangi uca gidileceğini ve hangi kimliğin yola yazılacağını —
/// imzayı doğrulamaz, içeriği değiştirmez. Asıl karar sunucunun.
///
/// [toString] token'ı yazmaz: QR yükü loglara düşmemeli.
class BoardingToken {
  const BoardingToken._(this.kind, this.subjectId, this.value);

  final BoardingTokenKind kind;

  /// Servis token'ında servis, işçi token'ında koltuk (seat assignment)
  /// kimliği.
  final String subjectId;

  /// Sunucuya `token` alanında giden ham değer.
  final String value;

  /// Sunucunun kabul ettiği en uzun token (`@Size(max = 256)`).
  static const int maxLength = 256;

  /// Bağlantının host'u.
  static const String linkHost = 'board';

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );
  static final RegExp _segment = RegExp(r'^[A-Za-z0-9_-]+$');

  /// Okutulan ham metni çözer; sözleşmeye uymayan her şeyde `null`.
  ///
  /// Kabul edilenler: çalışan flavor'ın tam şemasıyla
  /// `{appScheme}://board?t=<token>` (deep link sözleşmesi: host'tan sonra
  /// yol yok, tek `t`) ya da çıplak token. Başka flavor'ın şeması (staging
  /// uygulamasında `koala://`) reddedilir — o QR başka ortamın sunucusuna
  /// ait.
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

  /// Çıplak token değerini çözer.
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

/// Binişe eklenen konumun en büyük yaşı. Anlık konum alınamazsa son bilinen
/// konum yalnız bundan gençse kullanılır; daha eskisi "durağa uzak"
/// bayrağını yanlış üretir, binişi konumsuz göndermek daha doğru.
const Duration boardingLocationMaxAge = Duration(minutes: 2);

/// Biniş POST'larının `clientEventId`'si: rastgele UUID v4. Aynı kimlikle
/// yeniden deneme sunucuda güvenli (kayıtlı olay `replayed` döner).
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
