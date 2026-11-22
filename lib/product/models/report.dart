/// Şikayet gerekçesi; sunucu zorunlu tuttuğu için listeden seçiliyor.
enum ReportReason {
  spam('SPAM', 'Spam veya reklam'),
  harassment('HARASSMENT', 'Taciz, hakaret veya tehdit'),
  fraud('FRAUD', 'Dolandırıcılık'),
  offPlatformPayment('OFF_PLATFORM_PAYMENT', 'Platform dışı ödeme isteği'),
  inappropriateContent('INAPPROPRIATE_CONTENT', 'Uygunsuz içerik'),
  fakeProfile('FAKE_PROFILE', 'Sahte profil'),
  noShow('NO_SHOW', 'İşe gelmedi'),
  other('OTHER', 'Diğer'),

  /// Tanınmayan gerekçe; kodu boş ve [selectable] dışında, gönderilemez.
  unknown('', 'Bilinmeyen gerekçe');

  const ReportReason(this.code, this.displayName);

  final String code;

  final String displayName;

  /// [unknown] yalnız okurken var.
  static List<ReportReason> get selectable =>
      values.where((reason) => reason != ReportReason.unknown).toList();

  static ReportReason fromCode(Object? value) {
    return ReportReason.values.firstWhere(
      (reason) => reason.code == value,
      orElse: () => ReportReason.unknown,
    );
  }
}

/// İnceleme durumu; yalnız moderasyon değiştirir.
enum ReportStatus {
  open('OPEN', 'İnceleme bekliyor'),
  underReview('UNDER_REVIEW', 'İnceleniyor'),
  actioned('ACTIONED', 'İşlem yapıldı'),
  dismissed('DISMISSED', 'Kapatıldı'),

  unknown('', 'Bilinmiyor');

  const ReportStatus(this.code, this.displayName);

  final String code;
  final String displayName;

  static ReportStatus fromCode(Object? value) {
    return ReportStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => ReportStatus.unknown,
    );
  }
}

/// Tek şikayet; dört hedef alanından biri dolu.
class Report {
  const Report({
    required this.id,
    required this.reason,
    required this.status,
    this.reportedUserId,
    this.jobId,
    this.messageId,
    this.imageId,
    this.description,
    this.reviewNote,
    this.reviewedAt,
    this.createdAt,
  });

  final String id;

  final String? reportedUserId;

  final String? jobId;

  final String? messageId;

  /// Sunucu destekliyor ama hiçbir ekran doldurmuyor.
  final String? imageId;

  final ReportReason reason;

  final String? description;

  final ReportStatus status;

  /// Yalnız incelenmiş şikayette dolu.
  final String? reviewNote;

  final DateTime? reviewedAt;
  final DateTime? createdAt;

  /// Sunucu hedefin içeriğini döndürmediği için tür yazılıyor.
  String get targetLabel {
    if (reportedUserId != null) return 'Kullanıcı şikayeti';
    if (jobId != null) return 'İlan şikayeti';
    if (messageId != null) return 'Mesaj şikayeti';
    if (imageId != null) return 'Görsel şikayeti';
    return 'Şikayet';
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: '${json['id']}',
      reportedUserId: _asId(json['reportedUserId']),
      jobId: _asId(json['jobId']),
      messageId: _asId(json['messageId']),
      imageId: _asId(json['imageId']),
      reason: ReportReason.fromCode(json['reason']),
      description: json['description'] as String?,
      status: ReportStatus.fromCode(json['status']),
      reviewNote: json['reviewNote'] as String?,
      reviewedAt: _parseDate(json['reviewedAt']),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  static String? _asId(Object? value) => value == null ? null : '$value';

  static DateTime? _parseDate(Object? value) {
    return switch (value) {
      final String text => DateTime.tryParse(text),
      _ => null,
    };
  }
}

/// Sayfalı şikayet listesi (`PageDto<ReportDto>`).
class ReportPage {
  const ReportPage({
    this.reports = const [],
    this.page = 0,
    this.size = 0,
    this.totalElements = 0,
    this.totalPages = 0,
    this.first = true,
    this.last = true,
  });

  final List<Report> reports;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  factory ReportPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];

    return ReportPage(
      reports: content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map(Report.fromJson)
                .toList()
          : const [],
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      first: json['first'] as bool? ?? true,
      last: json['last'] as bool? ?? true,
    );
  }
}

/// Şikayetin hedefi. Sunucunun "en az bir hedef" kuralını yapısal olarak
/// karşılar: hedefsiz şikayet kurulamaz.
class ReportTarget {
  const ReportTarget._({
    required this.sheetTitle,
    required this.description,
    this.reportedUserId,
    this.jobId,
    this.messageId,
  });

  final String sheetTitle;

  final String description;

  final String? reportedUserId;
  final String? jobId;
  final String? messageId;

  factory ReportTarget.user({required String userId, String? name}) {
    return ReportTarget._(
      reportedUserId: userId,
      sheetTitle: 'Kullanıcıyı Şikayet Et',
      description: name == null || name.trim().isEmpty
          ? 'Bu kullanıcı hakkında bildirimde bulunuyorsun.'
          : '$name hakkında bildirimde bulunuyorsun.',
    );
  }

  factory ReportTarget.job({required String jobId, String? title}) {
    return ReportTarget._(
      jobId: jobId,
      sheetTitle: 'İlanı Şikayet Et',
      description: title == null || title.trim().isEmpty
          ? 'Bu ilan hakkında bildirimde bulunuyorsun.'
          : '"$title" ilanı hakkında bildirimde bulunuyorsun.',
    );
  }

  factory ReportTarget.message({required String messageId}) {
    return ReportTarget._(
      messageId: messageId,
      sheetTitle: 'Mesajı Şikayet Et',
      description: 'Seçtiğin mesaj hakkında bildirimde bulunuyorsun.',
    );
  }
}
