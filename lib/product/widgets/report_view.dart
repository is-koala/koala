import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/report_service.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/empty_state.dart';

/// Kullanıcının açtığı şikayetlerin listesi.
///
/// Ekranın kendisi değil gövdesi: `Scaffold` ve başlık çubuğu çağırana ait,
/// çünkü iki uygulamanın başlık çubuğu farklı kuruluyor — [SessionView] ve
/// [NotificationView] ile aynı düzen.
///
/// Şikayetin karşılığında ne yapıldığını kullanıcı buradan öğreniyor;
/// moderasyonun bıraktığı not da satırda duruyor.
class ReportView extends StatefulWidget {
  const ReportView({super.key, this.bottomPadding = AppSizes.space});

  /// Listenin altındaki boşluk. İşveren tarafında navbar'ın altında
  /// kalmasın diye büyütülüyor.
  final double bottomPadding;

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final ReportService _service = ReportService();
  final ScrollController _controller = ScrollController();

  List<Report> _reports = const [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _page = 0;
  String? _errorMessage;

  /// Listenin sonuna bu kadar kala sonraki sayfa isteniyor; kullanıcı dibe
  /// değmeden yükleme başlasın.
  static const double _loadMoreThreshold = 240;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;

    final remaining =
        _controller.position.maxScrollExtent - _controller.position.pixels;

    if (remaining <= _loadMoreThreshold) _loadMore();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final page = await _service.fetchMyReports();
      if (!mounted) return;
      setState(() {
        _reports = page.reports;
        _page = page.page;
        _hasMore = !page.last;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Sonraki sayfayı listenin sonuna ekler.
  ///
  /// Hata durumunda liste olduğu gibi kalıyor ve sayfalama duruyor: elde
  /// duran şikayetleri hata ekranıyla değiştirmek, kullanıcının görebildiği
  /// bilgiyi de alırdı. Yenilemek için aşağı çekmek yeterli.
  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final page = await _service.fetchMyReports(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _reports = [..._reports, ...page.reports];
        _page = page.page;
        _hasMore = !page.last;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _hasMore = false);
      AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Üç durum ayrı ayrı çiziliyor: yükleniyor, açılamadı, gerçekten boş.
    if (_isLoading && _reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reports.isEmpty && _errorMessage != null) {
      return EmptyState(
        icon: AppIcons.alert,
        title: 'Şikayetler açılamadı',
        description: _errorMessage!,
        action: TextButton(
          onPressed: () => _load(),
          child: const Text('Tekrar Dene'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: _reports.isEmpty
          ? const EmptyState(
              icon: AppIcons.shield,
              title: 'Şikayetin yok',
              description:
                  'Bir kullanıcıyı, ilanı ya da mesajı şikayet edersen '
                  'burada görünecek.',
            )
          : ListView.builder(
              controller: _controller,
              padding: EdgeInsets.only(
                top: AppSizes.spaceSmall,
                bottom: widget.bottomPadding,
              ),
              itemCount: _reports.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _reports.length) {
                  return const Padding(
                    padding: AppPadding.primaryAll,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                return _tile(_reports[index]);
              },
            ),
    );
  }

  Widget _tile(Report report) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.dividerColor, width: 1),
        ),
      ),
      child: Padding(
        padding: AppPadding.tileTall,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppSizes.iconTile,
              height: AppSizes.iconTile,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.accentColor.withValues(
                  alpha: AppColors.surfaceTintAlpha,
                ),
                borderRadius: AppRadius.innerCircular,
              ),
              child: AppIcon(
                AppIcons.flag,
                size: AppSizes.icon,
                color: context.accentColor,
              ),
            ),
            const SizedBox(width: AppSizes.space),
            Expanded(child: _tileContent(report)),
          ],
        ),
      ),
    );
  }

  Widget _tileContent(Report report) {
    final description = report.description;
    final reviewNote = report.reviewNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                report.reason.displayName,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            _statusBadge(report.status),
          ],
        ),
        const SizedBox(height: AppSizes.spaceTiny),
        Text(
          _subtitle(report),
          style: context.textTheme.labelMedium?.copyWith(
            color: context.textTertiary,
          ),
        ),
        if (description != null && description.trim().isNotEmpty) ...[
          const SizedBox(height: AppSizes.spaceTiny),
          Text(
            description,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
        // Moderasyonun notu yalnızca incelenmiş şikayette dolu; kullanıcının
        // en çok merak ettiği satır bu.
        if (reviewNote != null && reviewNote.trim().isNotEmpty) ...[
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            reviewNote,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  /// Hedef türü ve açılma tarihi. Sunucu hedefin kendisini döndürmediği için
  /// satırda ilanın başlığı değil "İlan şikayeti" yazıyor.
  String _subtitle(Report report) {
    final createdAt = report.createdAt;
    if (createdAt == null) return report.targetLabel;

    return '${report.targetLabel} · ${createdAt.asRelative}';
  }

  Widget _statusBadge(ReportStatus status) {
    final color = _statusColor(status);

    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        status.displayName,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Durumun rengi. Sunum tarafı modelde değil burada: `ReportStatus`
  /// sunucunun sözleşmesi, renk uygulamanın kararı.
  Color _statusColor(ReportStatus status) {
    return switch (status) {
      ReportStatus.open => AppColors.info,
      ReportStatus.underReview => AppColors.warning,
      ReportStatus.actioned => AppColors.success,
      // "Kapatıldı" bir başarı da başarısızlık da değil; nötr kalıyor.
      ReportStatus.dismissed || ReportStatus.unknown => context.textTertiary,
    };
  }
}
