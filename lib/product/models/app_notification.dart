/// Bildirimin hangi kanaldan gönderildiği. Backend `NotificationChannel`
/// karşılığı.
///
/// Adı yanıltıcı gelmesin: bu, bildirimin **gönderim yolu**, kullanıcının
/// onu nerede gördüğü değil. Sunucu her olay için birden fazla kayıt
/// üretebiliyor ve akış hepsini döndürüyor — hangisinin gösterileceği
/// çağıranın kararı.
enum NotificationChannel {
  email('EMAIL'),
  sms('SMS'),
  push('PUSH'),

  /// Uygulama içi bildirim. Akış **yalnızca bunu** döndürüyor; e-posta ve
  /// push kayıtları gönderim kaydı olarak duruyor ama listeye girmiyor.
  inApp('IN_APP'),

  /// Sunucu tanımadığımız bir kanal eklerse buraya düşüyor. Bilinmeyeni
  /// var olan bir kanala yamamak, akışı sessizce yanlış gösterirdi.
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

/// Bildirimin konusu. Backend `NotificationCategory` karşılığı.
///
/// Kullanıcıya görünen tek sınıflandırma bu, o yüzden Türkçe adları da
/// burada duruyor.
enum NotificationCategory {
  accountSecurity('ACCOUNT_SECURITY', 'Hesap Güvenliği'),
  applicationUpdates('APPLICATION_UPDATES', 'Başvurular'),
  identityVerification('IDENTITY_VERIFICATION', 'Kimlik Doğrulama'),
  marketings('MARKETINGS', 'Kampanyalar'),
  companyUpdates('COMPANY_UPDATES', 'Şirketler'),
  jobAlerts('JOB_ALERTS', 'İş Alarmları'),
  newsletter('NEWSLETTER', 'Bülten'),

  /// Sunucu yeni bir kategori eklerse buraya düşüyor. Var olan bir
  /// kategoriye yamasaydık bildirim yanlış başlık altında görünürdü.
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

/// Gönderimin durumu. Backend `NotificationStatus` karşılığı.
///
/// Bu, gönderim hattının durumu — kullanıcının bildirimi okuyup okumadığı
/// değil. Okundu bilgisi [AppNotification.isRead] üzerinden `readAt`
/// alanından geliyor.
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

/// Bildirime dokunulduğunda gidilecek kaydın türü. Backend
/// `NotificationTargetType` karşılığı.
enum NotificationTargetType {
  job('JOB'),
  jobApplication('JOB_APPLICATION'),
  jobAssignment('JOB_ASSIGNMENT'),
  conversation('CONVERSATION'),
  user('USER'),
  companyContactInvitation('COMPANY_CONTACT_INVITATION'),

  /// Hedefi olmayan ya da tanınmayan tür. Satır tıklanamaz kalıyor.
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

/// Kullanıcıya gönderilmiş tek bir bildirim. Backend `NotificationDto`
/// karşılığı.
///
/// Sınıf adı `Notification` değil: Flutter'ın kendi `Notification` sınıfı
/// (`NotificationListener`'ın taşıdığı) ile çakışırdı.
///
/// İki metin taşıyor: [subject] neyle ilgili olduğunu (ilanın başlığı),
/// [body] ne olduğunu ("Başvurunuz kabul edildi") söylüyor. Nereye
/// gidileceği [targetType] ve [targetId] ile geliyor.
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

  /// Başlık: bildirimin neyle ilgili olduğu, genelde ilanın adı. Hedefi
  /// olmayan bildirimlerde (ör. kimlik doğrulandı) boş geliyor.
  final String? subject;

  /// Olayın kendisi: "Başvurunuz kabul edildi" gibi.
  final String? body;

  /// Dokununca gidilecek kaydın türü; hedefi yoksa
  /// [NotificationTargetType.none].
  final NotificationTargetType targetType;

  final String? targetId;

  /// Dokunulabilir mi. Hedefi olmayan bildirim tıklanınca hiçbir yere
  /// gitmemeli — basılıp da bir şey olmaması bozuk izlenimi veriyor.
  bool get hasTarget =>
      targetType != NotificationTargetType.none && targetId != null;

  final DateTime? sentAt;

  /// Okunma anı. Tek tek (`POST .../{id}/read`) ya da toptan
  /// (`POST .../read`) işaretlenebiliyor.
  final DateTime? readAt;

  bool get isRead => readAt != null;

  /// Gösterilecek bir başlığı var mı. Boş satır listede yer kaplamamalı.
  bool get hasSubject => subject != null && subject!.trim().isNotEmpty;

  bool get hasBody => body != null && body!.trim().isNotEmpty;

  /// Listedeki başlık. Bildirimin başlığı boşsa olayın kendisi başlığa
  /// çıkıyor; ikisi de boşsa kategori adı kalıyor.
  String get title => hasSubject
      ? subject!
      : hasBody
      ? body!
      : category.displayName;

  /// Başlığın altındaki satır. Başlık zaten olayın kendisiyse tekrar
  /// yazılmıyor.
  String? get detail => hasSubject && hasBody ? body : null;

  /// Okunmuş kopyası. Tek bir alan değiştiği için tam bir `copyWith`
  /// yazılmadı; modelin geri kalanı sunucudan geliyor ve elde
  /// değiştirilmiyor.
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

/// Bildirim akışı. Backend `NotificationFeedDto` karşılığı.
///
/// Sayfa ile okunmamış sayısı **birlikte** geliyor: rozetteki sayı,
/// sayfalamadan bağımsız olarak kullanıcının toplam okunmamışını gösteriyor.
class NotificationFeed {
  const NotificationFeed({
    this.notifications = const [],
    this.unreadCount = 0,
    this.page = 0,
    this.totalElements = 0,
    this.last = true,
  });

  final List<AppNotification> notifications;

  /// Okunmamış toplam. Sayfadaki okunmamışların sayısı **değil** — sunucu
  /// bunu ayrıca sayıyor.
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
