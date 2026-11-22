/// Bildirimin **gönderim yolu** (`NotificationChannel`), kullanıcının onu
/// nerede gördüğü değil.
enum NotificationChannel {
  email('EMAIL'),
  sms('SMS'),
  push('PUSH'),

  /// Akış yalnız bunu döndürüyor.
  inApp('IN_APP'),

  /// Tanınmayan kanal; var olana yamamak akışı yanlış gösterirdi.
  unknown('');

  const NotificationChannel(this.code);

  final String code;

  static NotificationChannel fromCode(Object? value) {
    return NotificationChannel.values.firstWhere(
      (channel) => channel.code == value,
      orElse: () => NotificationChannel.unknown,
    );
  }
}

/// Bildirimin konusu; kullanıcıya görünen tek sınıflandırma.
enum NotificationCategory {
  accountSecurity('ACCOUNT_SECURITY', 'Hesap Güvenliği'),
  applicationUpdates('APPLICATION_UPDATES', 'Başvurular'),
  identityVerification('IDENTITY_VERIFICATION', 'Kimlik Doğrulama'),
  marketings('MARKETINGS', 'Kampanyalar'),
  companyUpdates('COMPANY_UPDATES', 'Şirketler'),
  jobAlerts('JOB_ALERTS', 'İş Alarmları'),
  newsletter('NEWSLETTER', 'Bülten'),

  /// Tanınmayan kategori; var olana yamamak yanlış başlık gösterirdi.
  other('', 'Diğer');

  const NotificationCategory(this.code, this.displayName);

  final String code;
  final String displayName;

  static NotificationCategory fromCode(Object? value) {
    return NotificationCategory.values.firstWhere(
      (category) => category.code == value,
      orElse: () => NotificationCategory.other,
    );
  }
}

/// Gönderim hattının durumu; okundu bilgisi [AppNotification.isRead]'de.
enum NotificationStatus {
  queued('QUEUED'),
  processing('PROCESSING'),
  sent('SENT'),
  failed('FAILED'),
  opened('OPENED'),
  clicked('CLICKED'),
  unknown('');

  const NotificationStatus(this.code);

  final String code;

  static NotificationStatus fromCode(Object? value) {
    return NotificationStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => NotificationStatus.unknown,
    );
  }
}

/// Dokununca gidilecek kaydın türü.
enum NotificationTargetType {
  job('JOB'),
  jobApplication('JOB_APPLICATION'),
  jobAssignment('JOB_ASSIGNMENT'),
  conversation('CONVERSATION'),
  user('USER'),
  companyContactInvitation('COMPANY_CONTACT_INVITATION'),

  /// Hedefsiz ya da tanınmayan; satır tıklanamaz.
  none('');

  const NotificationTargetType(this.code);

  final String code;

  static NotificationTargetType fromCode(Object? value) {
    return NotificationTargetType.values.firstWhere(
      (type) => type.code == value,
      orElse: () => NotificationTargetType.none,
    );
  }
}

/// Tek bildirim (`NotificationDto`). Adı `Notification` değil, Flutter'ınkiyle
/// çakışırdı. [subject] neyle ilgili, [body] ne olduğu.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.channel,
    required this.category,
    required this.status,
    this.subject,
    this.body,
    this.targetType = NotificationTargetType.none,
    this.targetId,
    this.sentAt,
    this.readAt,
  });

  final String id;
  final NotificationChannel channel;
  final NotificationCategory category;
  final NotificationStatus status;

  /// Genelde ilanın adı; hedefsiz bildirimlerde boş.
  final String? subject;

  final String? body;

  final NotificationTargetType targetType;

  final String? targetId;

  /// Hedefsiz bildirime basıp bir şey olmaması bozuk izlenimi verir.
  bool get hasTarget =>
      targetType != NotificationTargetType.none && targetId != null;

  final DateTime? sentAt;

  final DateTime? readAt;

  bool get isRead => readAt != null;

  bool get hasSubject => subject != null && subject!.trim().isNotEmpty;

  bool get hasBody => body != null && body!.trim().isNotEmpty;

  /// Başlık boşsa olay, o da boşsa kategori adı.
  String get title => hasSubject
      ? subject!
      : hasBody
      ? body!
      : category.displayName;

  /// Başlık zaten olaysa tekrar yazılmıyor.
  String? get detail => hasSubject && hasBody ? body : null;

  /// Okunmuş kopyası; model elde başka türlü değişmediği için tam `copyWith`
  /// yok.
  AppNotification copyWithRead(DateTime readAt) {
    return AppNotification(
      id: id,
      channel: channel,
      category: category,
      status: status,
      subject: subject,
      body: body,
      targetType: targetType,
      targetId: targetId,
      sentAt: sentAt,
      readAt: readAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: '${json['id']}',
      channel: NotificationChannel.fromCode(json['channel']),
      category: NotificationCategory.fromCode(json['category']),
      status: NotificationStatus.fromCode(json['status']),
      subject: json['subject'] as String?,
      body: json['body'] as String?,
      targetType: NotificationTargetType.fromCode(json['targetType']),
      targetId: json['targetId'] == null ? null : '${json['targetId']}',
      sentAt: _parseDate(json['sentAt']),
      readAt: _parseDate(json['readAt']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    return switch (value) {
      final String text => DateTime.tryParse(text),
      _ => null,
    };
  }
}

/// Bildirim akışı; okunmamış sayısı sayfalamadan bağımsız toplam.
class NotificationFeed {
  const NotificationFeed({
    this.notifications = const [],
    this.unreadCount = 0,
    this.page = 0,
    this.totalElements = 0,
    this.last = true,
  });

  final List<AppNotification> notifications;

  /// Sayfadakilerin değil toplamın sayısı.
  final int unreadCount;

  final int page;
  final int totalElements;
  final bool last;

  bool get hasUnread => unreadCount > 0;

  factory NotificationFeed.fromJson(Map<String, dynamic> json) {
    final page = json['notifications'];

    if (page is! Map<String, dynamic>) {
      return NotificationFeed(
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );
    }

    final content = page['content'];

    return NotificationFeed(
      notifications: content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map(AppNotification.fromJson)
                .toList()
          : const [],
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      page: page['page'] as int? ?? 0,
      totalElements: (page['totalElements'] as num?)?.toInt() ?? 0,
      last: page['last'] as bool? ?? true,
    );
  }
}
