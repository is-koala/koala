import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/core/widgets/job_detail_bottom_sheet.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/extensions/num_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

class JobCard extends StatelessWidget {
  final Job job;

  /// Dokununca ilan detayı açılsın mı. Başvuru ekranı gibi detaydan gelinen
  /// yerlerde kart yalnız özet; aynı detayı tekrar açmak geri tuşuyla
  /// karışıyordu.
  final bool openDetailOnTap;

  const JobCard({super.key, required this.job, this.openDetailOnTap = true});

  /// Kapak / kategori görseliyle metin arası.
  static const double _leadingGap = AppSizes.space;

  @override
  Widget build(BuildContext context) {
    final onTap = openDetailOnTap
        ? () => JobDetailBottomSheet.show(context, job)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space),
      child: Material(
        // Uygulamanın kart rengi; liste sayfasında da, haritadaki grup
        // listesinde (beyaz sheet) de zeminden ayrılıyor.
        color: context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: AppPadding.primaryAll,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _leading(),
                const SizedBox(width: _leadingGap),
                Expanded(child: _body(context)),
                const SizedBox(width: AppSizes.spaceSmall),
                _price(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Başlık, işveren ve bir satırlık özet: ne zaman, nerede, servis var mı.
  /// Kategori soldaki görselde; ayrı bir etiket (rozet) yok.
  Widget _body(BuildContext context) {
    final start = job.startDateTime?.toLocal();
    final distanceKm = job.distanceKm;
    final place = job.locationLabel;
    final employer = job.company ?? job.subtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          job.title,
          style: context.textTheme.titleSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSizes.smallGap),
        Text(
          employer,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSizes.spaceSmall),
        Wrap(
          spacing: AppSizes.space,
          runSpacing: AppSizes.spaceTiny,
          children: [
            if (start != null)
              _meta(context, AppIcons.calendar, start.asShortDateTime),
            // Uzaklık biliniyorsa o, yoksa ilçe/il. Çözünürlüğü ilanın
            // kesinliği belirliyor (`distanceLabel`): yuvarlanmış bir
            // koordinattan çıkan uzaklığı ondalıklı yazmak, veride olmayan
            // bir hassasiyeti iddia etmek olurdu.
            if (distanceKm != null)
              _meta(context, AppIcons.location, job.distanceLabel(distanceKm))
            else if (place != null)
              _meta(context, AppIcons.location, place),
            // `JobSummaryDto.hasShuttle` (is-koala/koala#197): ilanın
            // servisi var; ayrıntı ilan detayındaki ulaşım kartında.
            if (job.hasShuttle)
              _meta(
                context,
                AppIcons.bus,
                'Servis var',
                key: const ValueKey('job-card-shuttle'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _meta(
    BuildContext context,
    AppIconData icon,
    String label, {
    Key? key,
  }) {
    return Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: AppSizes.iconSmall, color: context.textSecondary),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Ücret ve birimi; sağ üstte, başlıkla aynı hizada.
  Widget _price(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '₺${job.price.asPrice}',
          style: context.textTheme.titleSmall?.copyWith(
            color: context.accentColor,
          ),
        ),
        Text(
          job.salaryType.displayName.toLowerCase(),
          style: context.textTheme.labelSmall?.copyWith(
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _leading() {
    final coverImageUrl = job.coverImageUrl;
    if (coverImageUrl == null || coverImageUrl.isEmpty) {
      return _categoryAvatar();
    }

    return ClipRRect(
      borderRadius: AppRadius.innerCircular,
      child: Image.network(
        coverImageUrl,
        width: AppSizes.thumbnail,
        height: AppSizes.thumbnail,
        fit: BoxFit.cover,
        semanticLabel: 'İlan kapağı',
        errorBuilder: (_, _, _) => _categoryAvatar(),
      ),
    );
  }

  Widget _categoryAvatar() {
    return CircleAvatar(
      backgroundColor: job.category.color,
      // Kategori rengi doygun ve temadan bağımsız; üstündeki ikon da öyle.
      child: AppIcon(
        job.category.icon,
        color: AppColors.onAccent,
        size: AppSizes.icon,
      ),
    );
  }
}
