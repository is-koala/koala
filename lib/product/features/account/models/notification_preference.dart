/// Bildirim kategorilerinin Türkçe adları; tanınmayan kod ham taşınıyor ve
/// genel etiket alıyor, İngilizce enum adı gösterilmiyor.
class NotificationCategoryLabels {
  const NotificationCategoryLabels._();

  static const Map<String, String> _labels = {
    'ACCOUNT_SECURITY': 'Hesap güvenliği',
    'APPLICATION_UPDATES': 'Başvuru ve iş güncellemeleri',
    'IDENTITY_VERIFICATION': 'Kimlik doğrulama',
    'COMPANY_UPDATES': 'Şirket güncellemeleri',
    'JOB_ALERTS': 'İş alarmları',
    'MESSAGES': 'Mesajlar',
    'MARKETINGS': 'Kampanya ve duyurular',
    'NEWSLETTER': 'Bülten',
  };

  static const String fallback = 'Diğer';

  static String of(String category) => _labels[category] ?? fallback;
}

class NotificationChannelLabels {
  const NotificationChannelLabels._();

  static const Map<String, String> _labels = {
    'EMAIL': 'E-posta',
    'SMS': 'SMS',
    'PUSH': 'Anlık bildirim',
    'IN_APP': 'Uygulama içi',
  };

  /// Sunucu sırasız gönderebiliyor.
  static const List<String> order = ['PUSH', 'IN_APP', 'EMAIL', 'SMS'];

  static String of(String channel) =>
      _labels[channel] ?? NotificationCategoryLabels.fallback;

  /// Listede olmayan kanal sona düşer.
  static int rank(String channel) {
    final index = order.indexOf(channel);
    return index == -1 ? order.length : index;
  }
}

/// Tek kategori-kanal kararı. [editable] `false` ise işlemsel bildirim (hesap
/// güvenliği, başvuru sonucu); sunucu kapatmayı `400` ile reddettiği için
/// anahtar kilitli çiziliyor.
class NotificationPreference {
  const NotificationPreference({
    required this.category,
    required this.kind,
    required this.channel,
    required this.enabled,
    required this.editable,
  });

  final String category;

  final String kind;

  final String channel;

  final bool enabled;

  final bool editable;

  /// Ticari ileti: her karar sunucuda rıza kaydına yazılıyor.
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

/// Aynı kategorinin kanalları; ekran kategori kartı çiziyor, sunucu düz liste
/// gönderiyor.
class NotificationPreferenceGroup {
  const NotificationPreferenceGroup({
    required this.category,
    required this.kind,
    required this.channels,
  });

  final String category;
  final String kind;

  final List<NotificationPreference> channels;

  String get title => NotificationCategoryLabels.of(category);

  /// Kullanıcı neyi kapatamadığını ve ticari iletide ne kabul ettiğini görsün.
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
              (a, b) =>
                  NotificationChannelLabels.rank(a.channel)
                      .compareTo(NotificationChannelLabels.rank(b.channel)),
            ),
        ),
    ];
  }
}
