import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/core/widgets/job_location_card.dart';
import 'package:koala/employee/core/widgets/job_transport_card.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/employee/features/home/models/job_share_link.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/saved_jobs_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/num_extensions.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/providers/job_gallery_provider.dart';
import 'package:koala/product/services/job_gallery_service.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/job_gallery_view.dart';
import 'package:koala/product/widgets/report_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

import 'dart:ui' show lerpDouble;

class JobDetailBottomSheet extends StatefulWidget {
  final Job job;
  final VoidCallback? onApply;
  final VoidCallback? onClose;
  final ScrollController? scrollController;
  final DraggableScrollableController? sheetController;
  final JobGalleryService? galleryService;

  /// Üretimde `null`, sheet kendi servisini kurar; testler sahte sunucu verir.
  final JobService? jobService;

  const JobDetailBottomSheet({
    super.key,
    required this.job,
    this.onApply,
    this.onClose,
    this.scrollController,
    this.sheetController,
    this.galleryService,
    this.jobService,
  });

  /// Kapalı ve açık yükseklikler. İçerik iki hâlde aynı; sürüklerken yalnız
  /// yükseklik değişiyor, içerik her karede dizilseydi sheet takılırdı.
  static const double _collapsedSize = 0.46;
  static const double _expandedSize = 0.95;

  static void show(BuildContext context, Job job) {
    final sheetController = DraggableScrollableController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        controller: sheetController,
        initialChildSize: _collapsedSize,
        minChildSize: 0.3,
        maxChildSize: _expandedSize,
        expand: false,
        snap: true,
        snapSizes: const [_collapsedSize, _expandedSize],
        builder: (context, scrollController) => JobDetailBottomSheet(
          job: job,
          onClose: () => Navigator.pop(context),
          scrollController: scrollController,
          sheetController: sheetController,
        ),
      ),
    );
  }

  @override
  State<JobDetailBottomSheet> createState() => _JobDetailBottomSheetState();
}

class _JobDetailBottomSheetState extends State<JobDetailBottomSheet> {
  /// Yalnız birincil düğmenin işini ve kaydet düğmesini belirliyor; eşik
  /// geçilince değişir, her karede değil.
  bool _isExpanded = false;

  /// Açılma oranı (0-1). Yalnız saydamlık, ölçek ve renk dinliyor
  /// ([_onProgress]); yerleşim değişmediği için sürüklerken sheet yeniden
  /// kurulmuyor.
  final ValueNotifier<double> _progress = ValueNotifier(0);
  late final JobGalleryProvider _galleryProvider;

  /// `GET /jobs` yalnız özet döndürüyor; alt bölümler ayrı istekle geliyor,
  /// başlık ve ücret özetten anında dolu.
  JobDetail? _detail;
  bool _detailLoading = true;
  String? _detailError;

  late final JobService _jobService = widget.jobService ?? JobService();

  Future<void> _loadDetail() async {
    setState(() {
      _detailLoading = true;
      _detailError = null;
    });

    try {
      final detail = await _jobService.getById(widget.job.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _detailLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _detailError = error.message;
        _detailLoading = false;
      });
    }
  }

  static const double _expandedThreshold =
      (JobDetailBottomSheet._collapsedSize +
          JobDetailBottomSheet._expandedSize) /
      2;

  static const Duration _animation = Duration(milliseconds: 200);

  /// Kısa: iki metin üst üste uzun görünmesin.
  static const Duration _textSwitch = Duration(milliseconds: 100);

  static const double _descriptionFont = 15;
  static const double _descriptionHeight = 1.6;

  /// İlanın iki ana bilgisi; ölçek slotlarına oturmayacak kadar büyük.
  static const double _companyFont = 14;
  static const double _titleFont = 28;
  static const double _priceFont = 30;

  /// Poppins'in ~1.5'i büyük yazıda gereksiz boşluk bırakıyor.
  static const double _titleHeight = 1.2;
  static const double _priceHeight = 1.1;

  static const double _handleArea = AppSizes.spaceLarge;
  static const double _headerArea = 56;

  /// Yazı boyutu değil ölçek değişiyor: satırlar yeniden kırılmıyor.
  static const double _titleScaleMin = 24 / _titleFont;
  static const double _priceScaleMin = 26 / _priceFont;

  @override
  void initState() {
    super.initState();
    _galleryProvider = JobGalleryProvider(service: widget.galleryService)
      ..addListener(_onGalleryChanged)
      ..load(widget.job.id);
    widget.sheetController?.addListener(_onSheetChanged);
    _loadDetail();
  }

  @override
  void dispose() {
    _galleryProvider
      ..removeListener(_onGalleryChanged)
      ..dispose();
    widget.sheetController?.removeListener(_onSheetChanged);
    _progress.dispose();
    super.dispose();
  }

  void _onGalleryChanged() {
    if (mounted) setState(() {});
  }

  void _onSheetChanged() {
    final controller = widget.sheetController;
    if (controller == null || !controller.isAttached) return;
    _progress.value =
        ((controller.size - JobDetailBottomSheet._collapsedSize) /
                (JobDetailBottomSheet._expandedSize -
                    JobDetailBottomSheet._collapsedSize))
            .clamp(0.0, 1.0);
    final expanded = controller.size > _expandedThreshold;
    if (expanded != _isExpanded) setState(() => _isExpanded = expanded);
  }

  /// [child]'ı açılma oranıyla yeniden boyar; [child] her karede kurulmaz.
  Widget _onProgress(
    Widget child,
    Widget Function(double progress, Widget child) builder,
  ) {
    return ValueListenableBuilder<double>(
      valueListenable: _progress,
      child: child,
      builder: (context, progress, child) => builder(progress, child!),
    );
  }

  void _closeSheet() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: AppRadius.sheetTop,
      ),
      child: Column(
        children: [
          appBar(),
          body(context),
          bottomButtonsBar(context, _isExpanded),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Alt butonlar

  Container bottomButtonsBar(BuildContext context, bool isExpanded) {
    final savedJobsProvider = context.watch<SavedJobsProvider>();
    final applyProvider = context.watch<ApplyProvider>();
    final isSaved = savedJobsProvider.isSaved(widget.job.id);
    final alreadyApplied = applyProvider.hasApplied(widget.job.id);

    return Container(
      padding: AppPadding.bottomBar.copyWith(
        bottom: context.padding.bottom + AppPadding.bottomBar.bottom,
      ),
      decoration: BoxDecoration(
        color: context.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.barShadow,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedSize(
            duration: _animation,
            curve: Curves.easeOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(right: AppSizes.space),
                    child: _saveButton(savedJobsProvider, isSaved: isSaved),
                  )
                : const SizedBox(height: AppSizes.buttonHeightCompact),
          ),
          Expanded(
            child: _primaryButton(
              isExpanded: isExpanded,
              alreadyApplied: alreadyApplied,
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButton(SavedJobsProvider provider, {required bool isSaved}) {
    return SizedBox.square(
      dimension: AppSizes.buttonHeightCompact,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: isSaved
                ? context.accentColor.withValues(alpha: 0.15)
                : context.tileColor,
            borderRadius: AppRadius.primaryCircular,
          ),
          child: InkWell(
            borderRadius: AppRadius.primaryCircular,
            onTap: () => _toggleSave(provider),
            child: Center(
              child: AppIcon(
                AppIcons.bookmark,
                filled: isSaved,
                color: isSaved ? context.accentColor : context.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required bool isExpanded,
    required bool alreadyApplied,
  }) {
    return SizedBox(
      height: AppSizes.buttonHeightCompact,
      child: ElevatedButton(
        onPressed: alreadyApplied
            ? null
            : (isExpanded
                  ? () {
                      Navigator.pop(context);
                      context.push('/apply', extra: widget.job);
                    }
                  // Kapalıyken buton sheet'i açar.
                  : () {
                      widget.sheetController?.animateTo(
                        JobDetailBottomSheet._expandedSize,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.accentColor,
          foregroundColor: context.onAccentColor,
          disabledBackgroundColor: context.elevatedColor,
          disabledForegroundColor: context.textTertiary,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.primaryCircular,
          ),
          elevation: 0,
          // Renk butonun `foregroundColor`'ından gelsin ki pasif hâl doğru
          // çizilsin.
          textStyle: context.textTheme.titleSmall,
        ),
        child: AnimatedSwitcher(
          duration: _textSwitch,
          child: Text(
            alreadyApplied
                ? 'Başvuruldu ✓'
                : (isExpanded ? 'Başvur' : 'Detayları Gör'),
            key: ValueKey('$alreadyApplied-$isExpanded'),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- Gövde

  Expanded body(BuildContext context) {
    return Expanded(
      child: ListView(
        controller: widget.scrollController,
        padding: AppPadding.primaryHorizontal,
        children: [
          // Boşluk ritmi: grup içi 4/8, gruplar arası 12–16, bölümler arası 24.
          _companyRow(),
          const SizedBox(height: AppSizes.spaceTiny),
          _title(),
          const SizedBox(height: AppSizes.space),
          _typeAndPriceRow(),
          const SizedBox(height: AppSizes.spaceSmall),
          _quickFacts(),
          const SizedBox(height: AppSizes.spaceLarge),
          _sectionTitle('Açıklama'),
          _description(),
          ..._gallerySection(),
          if (_detailLoading) _detailPlaceholder(),
          if (_detailError != null) _detailErrorRow(),
          if (_detail?.duties != null) ...[
            const SizedBox(height: AppSizes.spaceLarge),
            _sectionTitle('Görevler'),
            Text(
              _detail!.duties!,
              style: context.textTheme.bodyMedium?.copyWith(
                fontSize: _descriptionFont,
                color: context.textSecondary,
                height: _descriptionHeight,
              ),
            ),
          ],
          const SizedBox(height: AppSizes.spaceLarge),
          _buildInfoCard('Tarih ve Saat', [
            ..._schedule(),
            // Yayın tarihi yalnız detayda.
            if (_detail?.createdAt != null)
              _appIconInfoRow(
                AppIcons.clock,
                'Yayın tarihi',
                _detail!.createdAt!.toLocal().asShortDate,
              ),
          ]),
          const SizedBox(height: _sectionGap),
          _buildInfoCard('Gereksinimler', [
            if (_detail?.minAge != null || _detail?.maxAge != null)
              _appIconInfoRow(
                AppIcons.user,
                'Yaş Aralığı',
                '${_detail?.minAge ?? ''}-${_detail?.maxAge ?? ''} yaş',
              ),
            _appIconInfoRow(
              AppIcons.work,
              'Deneyim',
              widget.job.experienceRequired ? 'Gerekli' : 'Gerekli Değil',
            ),
            _appIconInfoRow(
              AppIcons.shield,
              'Sigorta',
              widget.job.insuranceRequired ? 'Gerekli' : 'Gerekli Değil',
            ),
            if (_detail?.dressCode != null)
              _appIconInfoRow(AppIcons.dress, 'Kıyafet', _detail!.dressCode!),
          ]),
          if (widget.job.sector != null ||
              widget.job.position != null ||
              _headcount != null) ...[
            const SizedBox(height: _sectionGap),
            _buildInfoCard('İş Bilgileri', [
              if (widget.job.sector != null)
                _appIconInfoRow(
                  AppIcons.building,
                  'Sektör',
                  widget.job.sector!,
                ),
              if (widget.job.position != null)
                _appIconInfoRow(
                  AppIcons.personalCard,
                  'Pozisyon',
                  widget.job.position!,
                ),
              if (_headcount != null)
                _appIconInfoRow(
                  AppIcons.userMultiple,
                  'Aranan kişi',
                  '$_hiredCount / $_headcount alındı',
                ),
            ]),
          ],
          _locationCard(),
          // Ulaşım yalnız detayda; planı olmayan ilanda ve eski sunucuda
          // `null`.
          if (_detail?.transport != null) ...[
            const SizedBox(height: AppSizes.spaceLarge),
            JobTransportCard(transport: _detail!.transport!, plain: true),
          ],
          const SizedBox(height: AppSizes.spaceLarge),
        ],
      ),
    );
  }

  List<Widget> _gallerySection() {
    if (_galleryProvider.isEmpty) return const [];

    return [
      const SizedBox(height: AppSizes.spaceLarge),
      JobGalleryView(
        images: _galleryProvider.images,
        isLoading: _galleryProvider.isLoading,
        errorMessage: _galleryProvider.errorMessage,
        onRetry: () => _galleryProvider.load(widget.job.id, force: true),
      ),
    ];
  }

  /// Detay yüklenirken; özet zaten dolu, bekleyen yalnız alt bölümler.
  Widget _detailPlaceholder() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.spaceLarge),
      child: Center(
        child: SizedBox(
          width: AppSizes.icon,
          height: AppSizes.icon,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  /// Detay çekilemedi: özet kalır, eksik bölümlerin yerine hata ve tekrar dene.
  Widget _detailErrorRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceMedium),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _detailError!,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          GestureDetector(
            onTap: _loadDetail,
            child: Text(
              'Tekrar dene',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// İkon iyimser değişir; sunucu reddederse provider geri alır.
  Future<void> _toggleSave(SavedJobsProvider provider) async {
    final succeeded = await provider.toggleSave(widget.job);
    if (succeeded || !mounted) return;

    AppToast.error(context, provider.errorMessage ?? 'İşlem tamamlanamadı.');
  }

  /// Konumun bu görüntüleyene hangi kesinlikte verildiği. Kural istemcide
  /// **yeniden kurulmuyor**: yetkiyi tahmin etmek sunucudan ayrışırdı (ör.
  /// adresi açık şirket ilanında anonime de `EXACT`). Detay geldiyse onunki.
  AddressPrecision get _addressPrecision =>
      _detail?.addressPrecision ?? widget.job.addressPrecision;

  /// Açık adres, yoksa özetteki ilçe/il, o da yoksa koordinat.
  String _locationLabel() {
    final address = _detail?.addressLabel;
    if (address != null && address.isNotEmpty) return address;

    final summary = widget.job.locationLabel;
    if (summary != null && summary.isNotEmpty) return summary;

    if (!widget.job.hasLocation) return 'Konum belirtilmemiş';

    return widget.job.coordinateLabel;
  }

  /// İkisi de göndermiyorsa `null`, satır çizilmez.
  int? get _headcount => _detail?.headcount ?? widget.job.headcount;

  int get _hiredCount => _detail?.hiredCount ?? widget.job.hiredCount;

  String _formatDateTime(DateTime value) =>
      '${value.day}/${value.month}/${value.year} - '
      '${value.hour}:${value.minute.toString().padLeft(2, '0')}';

  Widget _handleBar() {
    return Center(
      child: Container(
        width: AppSizes.sheetHandleWidth,
        height: AppSizes.sheetHandleHeight,
        margin: const EdgeInsets.only(top: AppSizes.spaceSmall),
        decoration: BoxDecoration(
          color: context.dividerColor,
          borderRadius: BorderRadius.circular(AppSizes.sheetHandleHeight / 2),
        ),
      ),
    );
  }

  Widget _companyRow() {
    // Bireyselde şirket yok: ilanı açanın adı, o da yoksa kategori.
    final label =
        widget.job.company ??
        _detail?.employerName ??
        widget.job.category.displayName;

    // Şirket kimliği yalnız detayda; gelmediyse satır düz metin.
    final companyId = _detail?.company?.id;

    // İşveren türü adın önünde küçük ikon (bina / kişi).
    final isCompany = widget.job.employerType == JobEmployerType.company;

    return Row(
      children: [
        Semantics(
          label: 'İşveren türü: ${widget.job.employerType.displayName}',
          child: AppIcon(
            isCompany ? AppIcons.building : AppIcons.user,
            size: AppSizes.iconSmall,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Expanded(
          child: GestureDetector(
            onTap: companyId == null
                ? null
                : () => context.push('/company-detail', extra: companyId),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                fontSize: _companyFont,
                fontWeight: FontWeight.w500,
                color: companyId == null
                    ? context.textSecondary
                    : context.accentColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _title() {
    return _onProgress(
      Text(
        widget.job.title,
        style: context.textTheme.headlineSmall?.copyWith(
          fontSize: _titleFont,
          fontWeight: FontWeight.w700,
          height: _titleHeight,
        ),
      ),
      (progress, child) => Transform.scale(
        scale: lerpDouble(_titleScaleMin, 1, progress)!,
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _typeAndPriceRow() {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Kategori ve tür rozet değil düz metin.
          Expanded(
            child: Row(
              children: [
                AppIcon(
                  widget.job.category.icon,
                  size: AppSizes.iconSmall,
                  color: widget.job.category.color,
                ),
                const SizedBox(width: AppSizes.spaceTiny),
                Flexible(
                  child: Text(
                    '${widget.job.category.displayName} · '
                    '${widget.job.type.displayName}',
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.space),
          _onProgress(
            Text(
              '${widget.job.price.asPrice}₺',
              style: context.textTheme.displaySmall?.copyWith(
                fontSize: _priceFont,
                fontWeight: FontWeight.w700,
                height: _priceHeight,
                color: context.accentColor,
              ),
            ),
            (progress, child) => Transform.scale(
              scale: lerpDouble(_priceScaleMin, 1, progress)!,
              alignment: Alignment.centerRight,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  /// Kapalı hâlde karar için ilk iki soru: ne zaman, ne kadar uzakta. İkisi de
  /// özetten; olmayan satıra yer ayrılmaz.
  Widget _quickFacts() {
    final start = widget.job.startDateTime?.toLocal();
    final distance = widget.job.distanceKm;
    final place = widget.job.locationLabel;
    final facts = [
      if (start != null) (AppIcons.calendar, start.asShortDateTime),
      if (distance != null || (place != null && place.isNotEmpty))
        (
          AppIcons.location,
          [
            if (distance != null) widget.job.distanceLabel(distance),
            if (place != null && place.isNotEmpty) place,
          ].join(' · '),
        ),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();

    // Her bilgi kendi satırında; sığmaya göre yan yana/alt alta düşmesin.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < facts.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSizes.spaceTiny),
          Row(
            children: [
              AppIcon(
                facts[i].$1,
                size: AppSizes.iconSmall,
                color: context.accentColor,
              ),
              const SizedBox(width: AppSizes.spaceTiny),
              Expanded(
                child: Text(
                  facts[i].$2,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Text(title, style: context.textTheme.titleMedium),
    );
  }

  Widget _description() {
    return ValueListenableBuilder<double>(
      valueListenable: _progress,
      builder: (context, progress, _) => Text(
        _detail?.description ?? widget.job.subtitle,
        style: context.textTheme.bodyMedium?.copyWith(
          fontSize: _descriptionFont,
          color: Color.lerp(
            context.textTertiary,
            context.textSecondary,
            progress,
          ),
          height: _descriptionHeight,
        ),
      ),
    );
  }

  Widget _locationCard() {
    return Padding(
      padding: const EdgeInsets.only(top: _sectionGap),
      child: JobLocationCard(
        precision: _addressPrecision,
        label: _locationLabel(),
        plain: true,
      ),
    );
  }

  // ------------------------------------------------------------------ Başlık

  Widget appBar() {
    // Tutamaç ve düğme satırı üst üste: kapalıyken tutamaç, açıkken düğmeler
    // kadar yer kaplıyor. Kapatma ve şikayet kapalı hâlde görünmüyor; ilk
    // bakışta iş ve para görünsün.
    final buttons = Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceTiny),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Kapat',
              icon: AppIcon(AppIcons.chevronDown, color: context.textPrimary),
              onPressed: _closeSheet,
            ),
            const Spacer(),
            _reportButton(),
            _shareButton(),
          ],
        ),
      ),
    );
    final handle = Align(alignment: Alignment.topCenter, child: _handleBar());

    // `buttons` ve `handle` bir kez kuruluyor; sürüklerken yalnız yükseklik ve
    // saydamlık değişiyor.
    return ValueListenableBuilder<double>(
      valueListenable: _progress,
      builder: (context, progress, _) => SizedBox(
        height: lerpDouble(_handleArea, _headerArea, progress),
        child: IgnorePointer(
          ignoring: progress < 0.5,
          child: ClipRect(
            child: Stack(
              children: [
                Opacity(opacity: progress, child: buttons),
                Opacity(opacity: 1 - progress, child: handle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Başlık ve web'deki ilan bağlantısını paylaşır; uygulaması olan uygulamada,
  /// olmayan web'de açar.
  Widget _shareButton() {
    return Builder(
      builder: (buttonContext) => IconButton(
        tooltip: 'Paylaş',
        icon: AppIcon(AppIcons.share, color: context.textPrimary),
        onPressed: () => _share(buttonContext),
      ),
    );
  }

  Future<void> _share(BuildContext buttonContext) async {
    final link = JobShareLink.forJob(widget.job.id);
    // iPad'de paylaşım menüsü bir noktaya bağlanmalı.
    final box = buttonContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: JobShareLink.message(title: widget.job.title, link: link),
        subject: widget.job.title,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Widget _reportButton() {
    return IconButton(
      tooltip: 'İlanı Şikayet Et',
      icon: AppIcon(AppIcons.flag, color: context.textPrimary),
      onPressed: () => ReportSheet.show(
        context,
        ReportTarget.job(jobId: widget.job.id, title: widget.job.title),
      ),
    );
  }

  // -------------------------------------------------------------- Bilgi kartı

  /// Kartsız bilgi bölümü; satırların kendi alt boşluğu yüzünden [_sectionGap]
  /// o kadar kısa.
  Widget _buildInfoCard(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        const SizedBox(height: AppSizes.spaceTiny),
        ...children,
      ],
    );
  }

  static const double _sectionGap = AppSizes.spaceLarge - AppSizes.space;

  Widget _appIconInfoRow(AppIconData icon, String label, String value) {
    return _infoRowBody(
      AppIcon(icon, size: AppSizes.iconMedium, color: context.accentColor),
      label,
      value,
    );
  }

  /// İkisi de varsa noktalı çizgiyle küçük zaman çizelgesi.
  List<Widget> _schedule() {
    final start = widget.job.startDateTime;
    final end = widget.job.endDateTime;
    if (start == null || end == null) {
      return [
        if (start != null)
          _appIconInfoRow(
            AppIcons.calendar,
            'Başlangıç',
            _formatDateTime(start),
          ),
        if (end != null)
          _appIconInfoRow(AppIcons.calendarTick, 'Bitiş', _formatDateTime(end)),
      ];
    }

    return [
      _timelineRow(AppIcons.calendar, 'Başlangıç', _formatDateTime(start)),
      _timelineRow(
        AppIcons.calendarTick,
        'Bitiş',
        _formatDateTime(end),
        isLast: true,
      ),
    ];
  }

  Widget _timelineRow(
    AppIconData icon,
    String label,
    String value, {
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: AppSizes.iconMedium,
            child: Column(
              children: [
                AppIcon(
                  icon,
                  size: AppSizes.iconMedium,
                  color: context.accentColor,
                ),
                if (!isLast)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.spaceTiny,
                      ),
                      child: CustomPaint(
                        painter: _DottedLinePainter(color: context.accentColor),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.space),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.space),
              child: _infoTexts(label, value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTexts(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.textTheme.labelMedium),
        Text(
          value,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _infoRowBody(Widget icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space),
      child: Row(
        children: [
          icon,
          const SizedBox(width: AppSizes.space),
          Expanded(child: _infoTexts(label, value)),
        ],
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  const _DottedLinePainter({required this.color});

  final Color color;

  static const double _dot = 2;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.6);
    final x = size.width / 2;
    for (var y = _dot / 2; y < size.height; y += _dot + _gap) {
      canvas.drawCircle(Offset(x, y), _dot / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
