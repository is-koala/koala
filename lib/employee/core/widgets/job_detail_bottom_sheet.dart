import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/core/widgets/job_location_card.dart';
import 'package:koala/employee/core/widgets/job_transport_card.dart';
import 'package:koala/product/extensions/date_extensions.dart';
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
import 'package:provider/provider.dart';
import 'dart:ui' show lerpDouble;

class JobDetailBottomSheet extends StatefulWidget {
  final Job job;
  final VoidCallback? onApply;
  final VoidCallback? onClose;
  final ScrollController? scrollController;
  final DraggableScrollableController? sheetController;
  final JobGalleryService? galleryService;

  /// İlan detayının geldiği yer. Üretimde `null` — sheet kendi
  /// [JobService]'ini kuruyor; test sahte bir sunucuya bağlı olanı veriyor.
  ///
  /// Konum satırının kesinliği **detaydan** geliyor, yani hangi kesinliğin
  /// gösterildiği ancak detay yanıtı denetlenebildiğinde sınanabiliyor.
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

  /// Sheet'in kapalı ve tam açık yükseklikleri.
  ///
  /// İçerik iki hâlde de **aynı**: aynı boyutlar, aynı bölümler. Kapalı
  /// hâlde sheet yalnız alçak, alttaki bölümler pencerenin dışında kalıyor.
  /// Sürüklerken yalnız sheet'in yüksekliği değişiyor; eskiden dört metin
  /// kare kare büyüyor ve bölümler bir eşikte beliriyordu, sheet her karede
  /// baştan dizildiği için takılıyormuş gibi görünüyordu.
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
  /// Sheet açık uca yakın mı. Yalnız alttaki birincil düğmenin işini
  /// ("Detayları Gör" / "Başvur") ve kaydet düğmesini belirliyor; içerik buna
  /// bakmıyor. Yalnız eşik geçildiğinde değişiyor, sürüklemenin her
  /// karesinde değil.
  bool _isExpanded = false;

  /// Sheet'in kapalıdan (0) açığa (1) ne kadar açıldığı. Yalnız saydamlık,
  /// ölçek ve renk geçişleri dinliyor ([_onProgress]); bunlar yerleşimi
  /// değiştirmediği için hiçbir metin yeniden dizilmiyor ve sheet sürüklerken
  /// baştan kurulmuyor.
  final ValueNotifier<double> _progress = ValueNotifier(0);
  late final JobGalleryProvider _galleryProvider;

  /// `GET /jobs` yalnızca özet döndürüyor: açıklama, görevler, yaş aralığı ve
  /// adres bu ekran açıldığında ayrı bir istekle geliyor. Başlık ve ücret
  /// özetten geldiği için sheet anında dolu açılıyor, yalnızca alt bölümler
  /// bekliyor.
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

  /// Sheet bu boyutu geçince "açık" sayılıyor: kapalı ile açık uçların
  /// ortası.
  static const double _expandedThreshold =
      (JobDetailBottomSheet._collapsedSize +
          JobDetailBottomSheet._expandedSize) /
      2;

  static const Duration _animation = Duration(milliseconds: 200);

  /// Açıklama ve görevler metni.
  static const double _descriptionFont = 15;
  static const double _descriptionHeight = 1.6;

  /// Başlık ve fiyat. Ölçek slotlarına oturmuyorlar; ilanın iki ana bilgisi
  /// sayfanın geri kalanından belirgin büyük.
  static const double _companyFont = 14;
  static const double _titleFont = 28;
  static const double _priceFont = 30;

  /// Üst kısmın kapalı (yalnız tutamaç) ve açık (yalnız düğmeler)
  /// yükseklikleri.
  static const double _handleArea = AppSizes.spaceLarge;
  static const double _headerArea = 56;

  /// Kapalı hâlde başlık ve fiyatın ölçeği. Yazı boyutu değil ölçek
  /// değişiyor: metin bir bütün olarak küçülüyor, satırlar yeniden kırılmıyor.
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

  /// [child]'ı açılma oranıyla yeniden boyar; [child] her karede yeniden
  /// kurulmuyor.
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
          // Kaydet düğmesi sheet açılınca yandan kayarak geliyor.
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
              child: Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_border,
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
                  // Kapalıyken buton başvuru değil, sheet'i açma eylemi.
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
          // Metin rengi burada değil; butonun kendi foregroundColor'ı
          // uyguluyor, böylece pasif hâlde disabledForegroundColor geçerli
          // oluyor.
          textStyle: context.textTheme.titleSmall,
        ),
        // Metin yalnız sheet bir uca oturunca değişiyor; geçiş yumuşak.
        child: AnimatedSwitcher(
          duration: _animation,
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
          // Boşluk ritmi: grup içinde sıkı (4 / 8), gruplar arasında 16,
          // bölümler arasında 24, bölüm başlığından metnine 8.
          _companyRow(),
          const SizedBox(height: AppSizes.spaceTiny),
          _title(),
          const SizedBox(height: AppSizes.spaceMedium),
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
            Text('Görevler', style: context.textTheme.titleSmall),
            const SizedBox(height: AppSizes.spaceSmall),
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
            if (widget.job.startDateTime != null)
              _buildInfoRow(
                Icons.calendar_today,
                'Başlangıç',
                _formatDateTime(widget.job.startDateTime!),
              ),
            if (widget.job.endDateTime != null)
              _buildInfoRow(
                Icons.calendar_today,
                'Bitiş',
                _formatDateTime(widget.job.endDateTime!),
              ),
            // Yayın tarihi yalnızca detayda (`JobDetailDto.createdAt`);
            // özet taşımıyor, detay gelmeden satır yok.
            if (_detail?.createdAt != null)
              _appIconInfoRow(
                AppIcons.clock,
                'Yayın tarihi',
                _detail!.createdAt!.toLocal().asShortDate,
              ),
          ]),
          const SizedBox(height: AppSizes.spaceMedium),
          _buildInfoCard('Gereksinimler', [
            if (_detail?.minAge != null || _detail?.maxAge != null)
              _buildInfoRow(
                Icons.person,
                'Yaş Aralığı',
                '${_detail?.minAge ?? ''}-${_detail?.maxAge ?? ''} yaş',
              ),
            _buildInfoRow(
              Icons.work,
              'Deneyim',
              widget.job.experienceRequired ? 'Gerekli' : 'Gerekli Değil',
            ),
            _buildInfoRow(
              Icons.health_and_safety,
              'Sigorta',
              widget.job.insuranceRequired ? 'Gerekli' : 'Gerekli Değil',
            ),
            if (_detail?.dressCode != null)
              _buildInfoRow(Icons.checkroom, 'Kıyafet', _detail!.dressCode!),
          ]),
          if (widget.job.sector != null ||
              widget.job.position != null ||
              _headcount != null) ...[
            const SizedBox(height: AppSizes.spaceMedium),
            _buildInfoCard('İş Bilgileri', [
              if (widget.job.sector != null)
                _buildInfoRow(Icons.business, 'Sektör', widget.job.sector!),
              if (widget.job.position != null)
                _buildInfoRow(Icons.badge, 'Pozisyon', widget.job.position!),
              if (_headcount != null)
                _appIconInfoRow(
                  AppIcons.userMultiple,
                  'Aranan kişi',
                  '$_hiredCount / $_headcount alındı',
                ),
            ]),
          ],
          _locationCard(),
          // Ulaşım yalnız detayla geliyor (`JobDetailDto.transport`); planı
          // olmayan ilanda ve eski sunucuda alan `null`, kart yok.
          if (_detail?.transport != null) ...[
            const SizedBox(height: AppSizes.spaceMedium),
            JobTransportCard(transport: _detail!.transport!),
          ],
          SizedBox(height: context.padding.bottom + AppSizes.navBarClearance),
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

  /// Detay yüklenirken açıklamanın altında duran gösterge. Başlık, ücret ve
  /// kategori özetten geldiği için sheet zaten dolu görünüyor; bekleyen
  /// yalnızca alt bölümler.
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

  /// Detay çekilemediğinde: özet bilgiler ekranda kalıyor, yalnızca eksik
  /// bölümlerin yerine hata ve tekrar denemek için bir bağlantı geliyor.
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

  /// Kaydet/kaldır. İkon iyimser olarak hemen değişiyor; sunucu reddederse
  /// provider geri alıyor ve sebebi burada gösteriliyor.
  Future<void> _toggleSave(SavedJobsProvider provider) async {
    final succeeded = await provider.toggleSave(widget.job);
    if (succeeded || !mounted) return;

    AppToast.error(context, provider.errorMessage ?? 'İşlem tamamlanamadı.');
  }

  /// Sunucunun konumu bu görüntüleyene hangi kesinlikte verdiği.
  ///
  /// Kural istemcide **yeniden kurulmuyor**: kimin yetkili olduğuna sunucu
  /// karar veriyor ve cevabını bu bayrakla söylüyor. Yetkiyi burada tahmin
  /// etmek (oturum var mı, atanmış mıyım) sunucunun kuralından sessizce
  /// ayrışırdı — örneğin `isAddressPublic` işaretli bir şirket ilanında sunucu
  /// **anonim** ziyaretçiye de `EXACT` döndürüyor.
  ///
  /// Detay geldiyse onunki geçerli; gelmeden önce özetteki bayrak kullanılıyor.
  AddressPrecision get _addressPrecision =>
      _detail?.addressPrecision ?? widget.job.addressPrecision;

  /// Konum satırı. Detay geldiyse açık adres, gelmediyse özetteki ilçe/il,
  /// o da yoksa ham koordinat yazılıyor.
  String _locationLabel() {
    final address = _detail?.addressLabel;
    if (address != null && address.isNotEmpty) return address;

    final summary = widget.job.locationLabel;
    if (summary != null && summary.isNotEmpty) return summary;

    if (!widget.job.hasLocation) return 'Konum belirtilmemiş';

    return widget.job.coordinateLabel;
  }

  /// Aranan kişi sayısı: detay geldiyse onunki, gelmediyse özetteki.
  /// İkisi de göndermiyorsa (eski sunucu) `null` ve satır çizilmiyor.
  int? get _headcount => _detail?.headcount ?? widget.job.headcount;

  int get _hiredCount => _detail?.hiredCount ?? widget.job.hiredCount;

  String _formatDateTime(DateTime value) =>
      '${value.day}/${value.month}/${value.year} - '
      '${value.hour}:${value.minute.toString().padLeft(2, '0')}';

  /// Tutamaç: her iki hâlde de aynı, sheet'in sürüklenebildiğini söylüyor.
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
    // Bireysel ilanlarda şirket yok; o zaman ilanı açan kişinin adı, o da
    // gelmediyse kategori adı yazılıyor — satır hiç boş kalmıyor.
    final label =
        widget.job.company ??
        _detail?.employerName ??
        widget.job.category.displayName;

    // Şirket kimliği yalnızca ilan detayında var; liste ucu şirketin adını
    // döndürüyor, kimliğini değil. Detay gelmediyse satır düz metin kalıyor.
    final companyId = _detail?.company?.id;

    // İşveren türü rozet değil, adın önünde küçük bir ikon: kurumsalda bina,
    // bireyselde kişi. Ad bütün satırı alıyor ve kesilmiyor.
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
                decoration: companyId == null
                    ? TextDecoration.none
                    : TextDecoration.underline,
                decorationColor: context.accentColor,
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
          // Kategori ve iş türü rozet değil, düz metin: kategori ikonu kendi
          // renginde, yazı sönük. İşin ne olduğunu fiyatın yanında söylüyor.
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

  /// Kapalı hâlde bakan kişinin işe karar vermek için ilk sorduğu iki şey:
  /// ne zaman ve ne kadar uzakta. İkisi de özetten geliyor, detay
  /// beklenmiyor; olmayan satıra yer ayrılmıyor.
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

    return Padding(
      padding: EdgeInsets.zero,
      child: Wrap(
        spacing: AppSizes.spaceMedium,
        runSpacing: AppSizes.spaceSmall,
        children: [
          for (final (icon, label) in facts)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  icon,
                  size: AppSizes.iconSmall,
                  color: context.accentColor,
                ),
                const SizedBox(width: AppSizes.spaceTiny),
                Text(
                  label,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Text(title, style: context.textTheme.titleMedium),
    );
  }

  /// Kapalı hâlde sönük, açıldıkça normal rengine geçiyor; boyutu sabit.
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
      padding: const EdgeInsets.only(top: AppSizes.spaceLarge),
      child: JobLocationCard(
        precision: _addressPrecision,
        label: _locationLabel(),
      ),
    );
  }

  // ------------------------------------------------------------------ Başlık

  /// Sheet'in üstü: tutamaç, kapatma ve şikayet. İki hâlde de aynı yerde.
  Widget appBar() {
    // Tutamaç ve düğme satırı üst üste: kapalıyken yalnız tutamaç kadar,
    // açıkken yalnız düğmeler kadar yer kaplıyor. Eskiden tutamaç açık hâlde
    // görünmez ama yerini tutuyordu, düğme satırı da üstüne biniyordu; en
    // üstte büyük bir boşluk kalıyordu. Yükseklik açıldıkça büyüyor; bu yalnız
    // alttaki içeriği kaydırıyor, metin yeniden dizilmiyor. Kapatma ve
    // şikayet kapalı hâlde görünmüyor: bakan kişi ilk bakışta işi ve parayı
    // görmek istiyor.
    final buttons = Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceTiny),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Kapat',
              icon: Icon(Icons.keyboard_arrow_down, color: context.textPrimary),
              onPressed: _closeSheet,
            ),
            const Spacer(),
            _reportButton(),
          ],
        ),
      ),
    );
    final handle = Align(alignment: Alignment.topCenter, child: _handleBar());

    // `buttons` ve `handle` bir kez kuruluyor; sürüklerken yalnız yükseklik
    // ve saydamlık değişiyor, ikisi yeniden kurulmuyor.
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

  /// İlanı şikayet eder.
  ///
  Widget _reportButton() {
    return IconButton(
      tooltip: 'İlanı Şikayet Et',
      icon: AppIcon(AppIcons.flag, color: context.textSecondary),
      onPressed: () => ReportSheet.show(
        context,
        ReportTarget.job(jobId: widget.job.id, title: widget.job.title),
      ),
    );
  }

  // -------------------------------------------------------------- Bilgi kartı

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textTheme.titleSmall),
          const SizedBox(height: AppSizes.space),
          ...children,
        ],
      ),
    );
  }

  /// Eski satırlar Material `Icons` taşıyor; yenisi eklenmiyor
  /// (CONTRIBUTING). Yeni satırlar [AppIcon] ile çiziliyor, gövde aynı.
  Widget _appIconInfoRow(AppIconData icon, String label, String value) {
    return _infoRowBody(
      AppIcon(icon, size: AppSizes.iconMedium, color: context.accentColor),
      label,
      value,
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return _infoRowBody(
      Icon(icon, size: AppSizes.iconMedium, color: context.accentColor),
      label,
      value,
    );
  }

  Widget _infoRowBody(Widget icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space),
      child: Row(
        children: [
          icon,
          const SizedBox(width: AppSizes.space),
          Expanded(
            child: Column(
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
            ),
          ),
        ],
      ),
    );
  }
}
