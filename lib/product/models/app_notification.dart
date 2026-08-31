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

/// Kullanıcıya gönderilmiş tek bir bildirim. Backend `NotificationDto`
/// karşılığı.
///
/// Sınıf adı `Notification` değil: Flutter'ın kendi `Notification` sınıfı
/// (`NotificationListener`'ın taşıdığı) ile çakışırdı.
///
/// Taşıdığı metin tek bir alan — [subject]. Gövde, hedef ya da bağlantı
/// yok; sunucu bunları `templateParameters` içinde tutuyor ve yanıta
/// çıkarmıyor. Yani bir bildirime tıklandığında nereye gidileceği bugün
/// bilinemiyor.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.channel,
    required this.category,
    required this.status,
    this.subject,
    this.sentAt,
    this.readAt,
  });

  final String id;
  final NotificationChannel channel;
  final NotificationCategory category;
  final NotificationStatus status;

  /// Gösterilecek metin. Sunucuda kanala göre **farklı şey** yazıyor:
  /// e-posta kaydında olayın kendisi ("Başvurunuz kabul edildi"), push
  /// kaydında ilanın başlığı ("Garson aranıyor"). Boş gelebiliyor.
  final String? subject;

  final DateTime? sentAt;

  /// Okunma anı. Tek tek okundu işaretleme ucu yok — yalnızca hepsini
  /// birden işaretleyen `POST /users/me/notifications/read` var.
  final DateTime? readAt;

  bool get isRead => readAt != null;

  /// Gösterilecek bir metni var mı. Boş satır listede yer kaplamamalı.
  bool get hasSubject => subject != null && subject!.trim().isNotEmpty;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: '${json['id']}',
      channel: NotificationChannel.fromCode(json['channel']),
      category: NotificationCategory.fromCode(json['category']),
      status: NotificationStatus.fromCode(json['status']),
      subject: json['subject'] as String?,
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
