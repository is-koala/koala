import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/providers/map_explore_controller.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Harita üstündeki durum kartı ve arama sonuçları. Ayrı widget ki karar tek
/// yerde dursun ve `GoogleMap` olmadan sınansın.
///
/// **Durum kartı arama açıkken de çiziliyor:** yoksa arama sırasında dönen
/// `500` "Sonuç bulunamadı" gibi görünür; başarısız yükleme boş sonuçla aynı
/// görünmemeli (#33).
class MapExploreOverlay extends StatelessWidget {
  const MapExploreOverlay({
    super.key,
    required this.isSearching,
    required this.isLoading,
    this.isRefreshing = false,
    required this.errorMessage,
    required this.isTruncated,
    required this.jobs,
    required this.onRetry,
    required this.onJobTap,
  });

  final bool isSearching;

  final bool isLoading;

  /// Pinler ekrandayken kart yerine ince çizgi; her kaydırmada kart açıp
  /// kapatmak dikkat dağıtır.
  final bool isRefreshing;

  final String? errorMessage;

  final bool isTruncated;

  final List<Job> jobs;

  final VoidCallback onRetry;

  final ValueChanged<Job> onJobTap;

  static const double _maxHeightRatio = 0.4;

  static const double _elevation = 8;

  @override
  Widget build(BuildContext context) {
    final status = _statusCard(context);
    final showResults = isSearching && jobs.isNotEmpty;

    final refresh = isRefreshing && !isLoading ? _refreshBar(context) : null;

    if (status == null && !showResults && refresh == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (refresh != null) ...[
          refresh,
          if (status != null || showResults)
            const SizedBox(height: AppSizes.spaceSmall),
        ],
        ?status,
        if (status != null && showResults)
          const SizedBox(height: AppSizes.spaceSmall),
        if (showResults) _resultsCard(context),
      ],
    );
  }

  /// Yükleniyor ve hata her şeyin önünde. Kırpılma uyarısı sonuç listesinin
  /// **üstünde**, yerine değil.
  Widget? _statusCard(BuildContext context) {
    if (isLoading) {
      return _card(
        context,
        icon: AppIcons.search,
        message: 'Bu alandaki ilanlar aranıyor...',
        showSpinner: true,
      );
    }

    final error = errorMessage;
    if (error != null) {
      return _card(
        context,
        icon: AppIcons.alert,
        message: error,
        action: TextButton(
          onPressed: onRetry,
          child: Text(
            'Tekrar Dene',
            style: context.textTheme.labelLarge?.copyWith(
              color: context.accentColor,
            ),
          ),
        ),
      );
    }

    if (isTruncated) {
      return _card(
        context,
        icon: AppIcons.alert,
        message:
            'Bu alanda ${MapExploreController.mapPageSize} ilandan fazlası '
            'var; hepsini görmek için yaklaşın.',
      );
    }

    if (isSearching && jobs.isEmpty) return _noResultsCard(context);

    return null;
  }

  Widget _refreshBar(BuildContext context) {
    return ClipRRect(
      key: const ValueKey('map-refresh-bar'),
      borderRadius: AppRadius.secondaryCircular,
      child: LinearProgressIndicator(
        minHeight: AppSizes.refreshBar,
        color: context.accentColor,
        backgroundColor: context.backgroundColor,
        semanticsLabel: 'Bu alandaki ilanlar güncelleniyor',
      ),
    );
  }

  Widget _shell(BuildContext context, {required Widget child}) {
    return Material(
      elevation: _elevation,
      borderRadius: AppRadius.secondaryCircular,
      color: context.backgroundColor,
      child: child,
    );
  }

  Widget _resultsCard(BuildContext context) {
    return _shell(
      context,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * _maxHeightRatio,
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSmall),
          itemCount: jobs.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            indent: AppPadding.primary,
            endIndent: AppPadding.primary,
          ),
          itemBuilder: (context, index) => _resultTile(context, jobs[index]),
        ),
      ),
    );
  }

  Widget _resultTile(BuildContext context, Job job) {
    return ListTile(
      leading: Container(
        width: AppSizes.iconCircle,
        height: AppSizes.iconCircle,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: job.category.color.withValues(alpha: 0.15),
          borderRadius: AppRadius.smallCircular,
        ),
        child: AppIcon(
          job.category.icon,
          color: job.category.color,
          size: AppSizes.iconMedium,
        ),
      ),
      title: Text(
        job.title,
        style: context.textTheme.labelLarge,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${job.company ?? ''} • ${job.locationLabel ?? ''}',
        style: context.textTheme.labelMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '₺${job.price.toStringAsFixed(0)}',
        style: context.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.accentColor,
        ),
      ),
      onTap: () => onJobTap(job),
    );
  }

  Widget _noResultsCard(BuildContext context) {
    return _shell(
      context,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.searchList,
              size: AppSizes.iconLarge,
              color: context.textTertiary,
            ),
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              'Sonuç bulunamadı',
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              'Farklı bir arama terimi deneyin',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required AppIconData icon,
    required String message,
    bool showSpinner = false,
    Widget? action,
  }) {
    return _shell(
      context,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppPadding.primary,
          vertical: AppSizes.space,
        ),
        child: Row(
          children: [
            if (showSpinner)
              SizedBox.square(
                dimension: AppSizes.iconSmall,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.accentColor,
                ),
              )
            else
              AppIcon(
                icon,
                size: AppSizes.iconSmall,
                color: context.textSecondary,
              ),
            const SizedBox(width: AppSizes.spaceSmall),
            Expanded(
              child: Text(
                message,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
