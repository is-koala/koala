import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_card.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';

/// Haritada aynı noktada duran ilanların listesi.
///
/// Gruba dokununca kamera ilanları ayıracak kadar yaklaşıyor; ilanlar aynı
/// noktadaysa (yuvarlanmış yaklaşık konum, aynı bina) yakınlaşmak onları
/// ayırmıyor ve bu liste açılıyor. Satır liste sekmesindeki kartın aynısı;
/// dokununca ilanın ayrıntısı açılıyor.
class JobClusterSheet extends StatelessWidget {
  const JobClusterSheet({super.key, required this.jobs});

  final List<Job> jobs;

  /// Listenin ekranın en fazla ne kadarını kaplayacağı; arkadaki harita
  /// görünür kalsın ki kullanıcı hangi noktaya baktığını bilsin.
  static const double _maxHeightRatio = 0.6;

  static Future<void> show(BuildContext context, List<Job> jobs) {
    return AppBottomSheet.show<void>(
      context,
      builder: (_) => JobClusterSheet(jobs: jobs),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Bu noktada ${jobs.length} ilan',
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * _maxHeightRatio,
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: jobs.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AppSizes.spaceSmall),
          itemBuilder: (_, index) => JobCard(job: jobs[index]),
        ),
      ),
    );
  }
}
