import 'package:koala/employee/features/home/models/job_detail.dart';

/// Havuzdaki bir işçi. Backend `TalentPoolEntryDto` karşılığı.
///
/// İşçi [JobCreator] — `SafeUserDto` alanları zaten orada; ikinci bir kopya
/// çıkarılmıyor.
class TalentPoolEntry {
  const TalentPoolEntry({
    required this.id,
    required this.worker,
    this.companyId,
    this.note,
    this.createdAt,
  });

  final String id;
  final JobCreator worker;
  final String? companyId;
  final String? note;
  final DateTime? createdAt;

  TalentPoolEntry copyWith({
    String? id,
    JobCreator? worker,
    String? companyId,
    String? note,
    DateTime? createdAt,
  }) {
    return TalentPoolEntry(
      id: id ?? this.id,
      worker: worker ?? this.worker,
      companyId: companyId ?? this.companyId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory TalentPoolEntry.fromJson(Map<String, dynamic> json) {
    final worker = json['worker'];

    return TalentPoolEntry(
      id: '${json['id']}',
      worker: worker is Map<String, dynamic>
          ? JobCreator.fromJson(worker)
          : const JobCreator(id: '', firstName: '', lastName: ''),
      companyId: json['companyId'] as String?,
      note: json['note'] as String?,
      createdAt: _parseDate(json['createdAt']),
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// Sayfalı havuz yanıtı. Backend `PageDto<TalentPoolEntryDto>` karşılığı.
///
/// JSON anahtarları `JobPage` ile aynı: `content, page, size, totalElements,
/// totalPages, first, last`. Liste alanı içeriğe göre [entries].
class TalentPoolPage {
  const TalentPoolPage({
    this.entries = const [],
    this.page = 0,
    this.size = 0,
    this.totalElements = 0,
    this.totalPages = 0,
    this.first = true,
    this.last = true,
  });

  final List<TalentPoolEntry> entries;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  factory TalentPoolPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];

    return TalentPoolPage(
      entries: content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map(TalentPoolEntry.fromJson)
                .toList()
          : const [],
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      first: json['first'] as bool? ?? true,
      last: json['last'] as bool? ?? true,
    );
  }
}
