/// Bildirim kategorileri. Backend `NotificationCategory` enum'ının karşılığı.
///
/// Sunucu ileride yeni bir kategori eklerse uygulama patlamasın diye
/// tanınmayan kod [NotificationPreference.category]'de ham hâliyle taşınıyor
/// ve [NotificationCategoryLabels.of] ona genel bir Türkçe etiket veriyor —
/// İngilizce enum adını kullanıcıya göstermek yerine.
class NotificationCategoryLabels {
  const NotificationCategoryLabels._();

  static const Map<String, String> _labels = {
    'ACCOUNT_SECURITY': 'Hesap güvenliği',
    'APPLICATION_UPDATES': 'Başvuru ve iş güncellemeleri',
    'IDENTITY_VERIFICATION': 'Kimlik doğrulama',
    'COMPANY_UPDATES': 'Şirket güncellemeleri',
    'JOB_ALERTS': 'İş alarmları',
    'MARKETINGS': 'Kampanya ve duyurular',
    'NEWSLETTER': 'Bülten',
  };

  /// Tanınmayan kategori ve kanal için genel etiket.
  static const String fallback = 'Diğer';

  /// Kategorinin Türkçe adı; bilinmeyen kod [fallback].
  static String of(String category) => _labels[category] ?? fallback;
}

/// Bildirim kanalları. Backend `NotificationChannel` enum'ının karşılığı.
class NotificationChannelLabels {
  const NotificationChannelLabels._();

  static const Map<String, String> _labels = {
    'EMAIL': 'E-posta',
    'SMS': 'SMS',
    'PUSH': 'Anlık bildirim',
    'IN_APP': 'Uygulama içi',
  };

  /// Kanalların ekrandaki sırası; sunucu sırasız gönderebiliyor.
  static const List<String> order = ['PUSH', 'IN_APP', 'EMAIL', 'SMS'];

  static String of(String channel) =>
      _labels[channel] ?? NotificationCategoryLabels.fallback;

  /// [order]'daki yeri; listede olmayan kanal sona düşüyor.
  static int rank(String channel) {
    final index = order.indexOf(channel);
    return index == -1 ? order.length : index;
  }
}

/// Tek bir kategori-kanal kararı: `GET /users/me/notification-preferences`
/// satırı.
///
/// [editable] `false` ise satır işlemsel (`TRANSACTIONAL`) bir bildirim:
/// hesap güvenliği, başvuru sonucu gibi. Sunucu bunları kapatmaya çalışan
/// `PUT`'u `400` ile reddediyor; ekran anahtarı en baştan kilitli çiziyor.
class NotificationPreference {
  const NotificationPreference({
    required this.category,
    required this.kind,
    required this.channel,
    required this.enabled,
    required this.editable,
  });

  /// `ACCOUNT_SECURITY`, `JOB_ALERTS` gibi kategori kodu.
  final String category;

  /// `TRANSACTIONAL`, `ALERT` ya da `COMMERCIAL`.
  final String kind;

  /// `EMAIL`, `SMS`, `PUSH` ya da `IN_APP`.
  final String channel;

  final bool enabled;

  final bool editable;

  /// Ticari ileti kategorisi: her karar sunucuda rıza kaydına yazılıyor.
  bool get isCommercial => kind == 'COMMERCIAL';

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      category: json['category'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      editable: json['editable'] as bool? ?? false,
    );
  }

  /// Aynı kategori-kanal, farklı karar.
  NotificationPreference copyWith({required bool enabled}) {
    return NotificationPreference(
      category: category,
      kind: kind,
      channel: channel,
      enabled: enabled,
      editable: editable,
    );
  }
}

/// `PUT /users/me/notification-preferences` gövdesindeki tek satır.
class NotificationPreferenceWrite {
  const NotificationPreferenceWrite({
    required this.category,
    required this.channel,
    required this.enabled,
  });

  final String category;
  final String channel;
  final bool enabled;

  Map<String, dynamic> toJson() => {
    'category': category,
    'channel': channel,
    'enabled': enabled,
  };
}

/// Aynı kategorinin kanalları bir arada: ekran bir kategori kartı çiziyor,
/// sunucu düz liste gönderiyor.
class NotificationPreferenceGroup {
  const NotificationPreferenceGroup({
    required this.category,
    required this.kind,
    required this.channels,
  });

  final String category;
  final String kind;

  /// Kanal satırları, [NotificationChannelLabels.order] sırasında.
  final List<NotificationPreference> channels;

  String get title => NotificationCategoryLabels.of(category);

  /// Kartın altındaki açıklama: kullanıcı neyi kapatamadığını ve ticari
  /// iletide ne kabul ettiğini görsün.
  String? get hint {
    if (channels.every((row) => !row.editable)) {
      return 'İşlemsel bildirim: hesabınızla ilgili bu iletiler kapatılamaz.';
    }
    if (kind == 'COMMERCIAL') {
      return 'Ticari ileti izni. Açtığınızda tercihiniz tarih ve kanalla '
          'birlikte kaydedilir.';
    }
    return null;
  }

  /// Düz listeyi kategori sırasını koruyarak gruplar.
  static List<NotificationPreferenceGroup> groupAll(
    List<NotificationPreference> rows,
  ) {
    final byCategory = <String, List<NotificationPreference>>{};
    final kinds = <String, String>{};
    for (final row in rows) {
      byCategory.putIfAbsent(row.category, () => []).add(row);
      kinds.putIfAbsent(row.category, () => row.kind);
    }
    return [
      for (final entry in byCategory.entries)
        NotificationPreferenceGroup(
          category: entry.key,
          kind: kinds[entry.key] ?? '',
          channels: [...entry.value]
            ..sort(
              (a, b) => NotificationChannelLabels.rank(
                a.channel,
              ).compareTo(NotificationChannelLabels.rank(b.channel)),
            ),
        ),
    ];
  }
}
