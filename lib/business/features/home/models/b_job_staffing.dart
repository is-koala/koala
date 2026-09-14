import 'package:koala/employee/features/home/models/job.dart';

/// İlanın kontenjanı: aranan kişi sayısı ve şimdiye kadar işe alınan.
///
/// `JobSummaryDto.headcount` / `hiredCount` karşılığı. [Job] modeline
/// eklenmedi: aynı alanlar çalışan tarafı için ayrı bir değişiklikte oraya
/// giriyor (is-koala/koala#177); iki değişiklik aynı dosyaya dokunmasın diye
/// işveren listesi kendi okuyucusunu taşıyor. Çalışan tarafı yerleşince bu
/// sınıf `Job`'un kendi alanlarından beslenebilir.
class BJobStaffing {
  const BJobStaffing({this.headcount, this.hiredCount = 0});

  /// Alanları göndermeyen sunucu için: kontenjan bilinmiyor, kart o satırı
  /// çizmiyor.
  static const BJobStaffing unknown = BJobStaffing();

  /// Aranan kişi sayısı; sunucu göndermediyse `null`.
  final int? headcount;

  /// İşe alınan kişi sayısı.
  final int hiredCount;

  /// Kart "2/3 dolu" yazabilir mi. Kontenjan bilinmiyorsa hiçbir şey
  /// yazılmıyor; "2/— dolu" bir bilgi değil.
  bool get isKnown => headcount != null;

  /// Kontenjan doldu mu. Bilinmiyorsa `false`: dolu olmayan bir ilanı dolu
  /// göstermek yeni başvuruyu engellerdi.
  bool get isFull => headcount != null && hiredCount >= headcount!;

  /// `2/3 dolu`. Kontenjan bilinmiyorsa `null`.
  String? get label => isKnown ? '$hiredCount/$headcount dolu' : null;

  factory BJobStaffing.fromJson(Map<String, dynamic> json) {
    return BJobStaffing(
      headcount: (json['headcount'] as num?)?.toInt(),
      hiredCount: (json['hiredCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// `GET /users/me/jobs` satırı: paylaşılan [Job] özeti ve işveren kartının
/// ayrıca okuduğu kontenjan, aynı JSON'dan birlikte.
class BJobListEntry {
  const BJobListEntry({
    required this.job,
    this.staffing = BJobStaffing.unknown,
  });

  final Job job;
  final BJobStaffing staffing;

  factory BJobListEntry.fromJson(Map<String, dynamic> json) {
    return BJobListEntry(
      job: Job.fromJson(json),
      staffing: BJobStaffing.fromJson(json),
    );
  }
}

/// İşverenin ilan sayfası. Sayfalama alanları `JobPage` ile aynı; içerik
/// [BJobListEntry] olarak okunuyor.
class BJobListPage {
  const BJobListPage({
    this.entries = const [],
    this.page = 0,
    this.totalElements = 0,
    this.last = true,
  });

  final List<BJobListEntry> entries;
  final int page;
  final int totalElements;
  final bool last;

  /// Yalnızca ilan özetleri; sayfalama bilgisine gerek duymayan çağıranlar
  /// için.
  List<Job> get jobs => entries.map((entry) => entry.job).toList();

  factory BJobListPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];

    return BJobListPage(
      entries: content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map(BJobListEntry.fromJson)
                .toList()
          : const [],
      page: json['page'] as int? ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      last: json['last'] as bool? ?? true,
    );
  }
}
