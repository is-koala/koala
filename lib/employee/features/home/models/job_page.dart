import 'package:koala/employee/features/home/models/job.dart';

/// Sayfalı ilan yanıtı. Backend `PageDto<JobSummaryDto>` karşılığı.
///
/// Keşfet bugün yalnızca ilk sayfayı çiziyor; [last] ve [page] sonsuz kaydırma
/// eklendiğinde kullanılacak, o yüzden şimdiden taşınıyor.
class JobPage {
  const JobPage({
    this.jobs = const [],
    this.page = 0,
    this.size = 0,
    this.totalElements = 0,
    this.totalPages = 0,
    this.first = true,
    this.last = true,
  });

  final List<Job> jobs;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  factory JobPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];

    return JobPage(
      jobs: content is List
          ? content.whereType<Map<String, dynamic>>().map(Job.fromJson).toList()
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
