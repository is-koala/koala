/// Şikayetin gerekçesi. Backend `ReportReason` karşılığı.
///
/// Sunucu gerekçeyi zorunlu tutuyor (`CreateReportDto.reason` `@NotNull`),
/// bu yüzden listeden seçiliyor — serbest metin değil.
enum ReportReason {
  spam('SPAM', 'Spam veya reklam'),
  harassment('HARASSMENT', 'Taciz, hakaret veya tehdit'),
  fraud('FRAUD', 'Dolandırıcılık'),
  offPlatformPayment('OFF_PLATFORM_PAYMENT', 'Platform dışı ödeme isteği'),
  inappropriateContent('INAPPROPRIATE_CONTENT', 'Uygunsuz içerik'),
  fakeProfile('FAKE_PROFILE', 'Sahte profil'),
  noShow('NO_SHOW', 'İşe gelmedi'),
  other('OTHER', 'Diğer'),

  /// Sunucu yeni bir gerekçe eklerse buraya düşüyor. Var olan bir gerekçeye
  /// yamamak, kullanıcıya kendi şikayetini yanlış sebeple gösterirdi.
  ///
  /// Kodu boş: [selectable] bu değeri listeden çıkarıyor, yani kullanıcı
  /// hiçbir zaman bunu seçip sunucuya gönderemiyor.
  unknown('', 'Bilinmeyen gerekçe');

  const ReportReason(this.code, this.displayName);

  /// Backend'in beklediği değer.
  final String code;

  /// Kullanıcıya gösterilen ad.
  final String displayName;

  /// Şikayet formunda seçilebilen gerekçeler.
  ///
  /// [unknown] yalnızca **okurken** var: sunucuya gönderilirse `400` olurdu.
  static List<ReportReason> get selectable =>
      values.where((reason) => reason != ReportReason.unknown).toList();

  static ReportReason fromCode(Object? value) {
    return ReportReason.values.firstWhere(
      (reason) => reason.code == value,
      orElse: () => ReportReason.unknown,
    );
  }
}

/// Şikayetin inceleme durumu. Backend `ReportStatus` karşılığı.
///
/// Durumu yalnızca moderasyon değiştiriyor; uygulama okuyor.
enum ReportStatus {
  open('OPEN', 'İnceleme bekliyor'),
  underReview('UNDER_REVIEW', 'İnceleniyor'),
  actioned('ACTIONED', 'İşlem yapıldı'),
  dismissed('DISMISSED', 'Kapatıldı'),

  /// Sunucu yeni bir durum eklerse buraya düşüyor; rozet "Bilinmiyor"
  /// yazıyor, uygulama çökmüyor.
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

/// Açılmış tek bir şikayet. Backend `ReportDto` karşılığı.
///
/// Dört hedef alanından biri dolu: şikayet ya bir kullanıcıya, ya bir ilana,
/// ya bir mesaja ya da bir görsele işaret ediyor.
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

  /// Şikayet edilen kullanıcı.
  final String? reportedUserId;

  /// Şikayet edilen ilan.
  final String? jobId;

  /// Şikayet edilen mesaj.
  final String? messageId;

  /// Şikayet edilen görsel. Sunucu destekliyor; uygulamada şirket galerisi
  /// yönetilmediği için hiçbir ekran bu alanı doldurmuyor.
  final String? imageId;

  final ReportReason reason;

  /// Kullanıcının yazdığı açıklama; isteğe bağlı, sunucuda en fazla 2000
  /// karakter.
  final String? description;

  final ReportStatus status;

  /// Moderasyonun bıraktığı not. Yalnızca incelenmiş şikayetlerde dolu.
  final String? reviewNote;

  final DateTime? reviewedAt;
  final DateTime? createdAt;

  /// Şikayetin neye açıldığı; listede gerekçenin altında yazıyor.
  ///
  /// Sunucu hedefin kendisini (ilanın başlığı, mesajın metni) döndürmüyor,
  /// yalnızca kimliğini — bu yüzden tür yazılıyor, içerik değil.
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

/// Sayfalı şikayet listesi. Backend `PageDto<ReportDto>` karşılığı.
///
/// Alan adları sunucunun `PageDto`'suyla birebir; desen
/// `ConversationPage` ile aynı.
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

/// Şikayetin işaret ettiği kayıt.
///
/// Sunucu dört hedef alanından **en az birini** zorunlu tutuyor
/// (`CreateReportDto.isPointingAtSomething()`). Bu sınıf o kuralı istemcide
/// yapısal olarak karşılıyor: hedefsiz bir şikayet kurulamıyor, yani
/// "hiçbir şeye işaret etmeyen şikayet" hatası sunucuya hiç gitmiyor.
///
/// Görsel şikayeti (`imageId`) burada yok: şirket galerisi mobilde
/// yönetilmiyor, alan yalnızca serviste duruyor.
class ReportTarget {
  const ReportTarget._({
    required this.sheetTitle,
    required this.description,
    this.reportedUserId,
    this.jobId,
    this.messageId,
  });

  /// Şikayet formunun başlığı.
  final String sheetTitle;

  /// Başlığın altında, neyin şikayet edileceğini söyleyen satır.
  final String description;

  final String? reportedUserId;
  final String? jobId;
  final String? messageId;

  /// Bir kullanıcıyı şikayet eder.
  factory ReportTarget.user({required String userId, String? name}) {
    return ReportTarget._(
      reportedUserId: userId,
      sheetTitle: 'Kullanıcıyı Şikayet Et',
      description: name == null || name.trim().isEmpty
          ? 'Bu kullanıcı hakkında bildirimde bulunuyorsun.'
          : '$name hakkında bildirimde bulunuyorsun.',
    );
  }

  /// Bir ilanı şikayet eder.
  factory ReportTarget.job({required String jobId, String? title}) {
    return ReportTarget._(
      jobId: jobId,
      sheetTitle: 'İlanı Şikayet Et',
      description: title == null || title.trim().isEmpty
          ? 'Bu ilan hakkında bildirimde bulunuyorsun.'
          : '"$title" ilanı hakkında bildirimde bulunuyorsun.',
    );
  }

  /// Tek bir mesajı şikayet eder.
  factory ReportTarget.message({required String messageId}) {
    return ReportTarget._(
      messageId: messageId,
      sheetTitle: 'Mesajı Şikayet Et',
      description: 'Seçtiğin mesaj hakkında bildirimde bulunuyorsun.',
    );
  }
}
