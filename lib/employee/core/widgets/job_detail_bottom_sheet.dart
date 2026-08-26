import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/saved_jobs_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/num_extensions.dart';
import 'package:provider/provider.dart';

class JobDetailBottomSheet extends StatefulWidget {
  final Job job;
  final VoidCallback? onApply;
  final VoidCallback? onClose;
  final ScrollController? scrollController;
  final DraggableScrollableController? sheetController;

  const JobDetailBottomSheet({
    super.key,
    required this.job,
    this.onApply,
    this.onClose,
    this.scrollController,
    this.sheetController,
  });

  /// Sheet'in kapalı ve tam açık yükseklikleri. Genişleme oranı bu ikisi
  /// arasında normalize ediliyor; içerideki animasyonların hepsi o orana bakar.
  static const double _collapsedSize = 0.4;
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
  double _sheetSize = 0.5;

  /// Genişleme oranının hangi eşikten sonra "açık" sayılacağı. Açıkken ek
  /// bölümler ve kaydet butonu görünür.
  static const double _expandedThreshold = 0.3;

  static const Duration _animation = Duration(milliseconds: 200);

  // Sheet açılırken büyüyen metinlerin uç değerleri. Ölçek slotlarına
  // oturmuyorlar çünkü ikisi arasında sürekli olarak interpolasyon yapılıyor.
  static const double _companyFontMin = 13;
  static const double _companyFontMax = 14;
  static const double _titleFontMin = 22;
  static const double _titleFontMax = 28;
  static const double _priceFontMin = 26;
  static const double _priceFontMax = 30;
  static const double _descriptionFontMin = 14;
  static const double _descriptionFontMax = 15;
  static const double _descriptionHeightMin = 1.5;
  static const double _descriptionHeightMax = 1.6;

  /// Sheet başlığının kapalı ve açık yükseklikleri.
  static const double _headerHeightMin = 8;
  static const double _headerHeightMax = 64;

  @override
  void initState() {
    super.initState();
    widget.sheetController?.addListener(_onSheetChanged);
  }

  @override
  void dispose() {
    widget.sheetController?.removeListener(_onSheetChanged);
    super.dispose();
  }

  void _onSheetChanged() {
    if (widget.sheetController != null) {
      setState(() {
        _sheetSize = widget.sheetController!.size;
      });
    }
  }

  void _closeSheet() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // 0.5 ile 0.95 arasında normalize et (0.0 - 1.0)
    final expandProgress =
        ((_sheetSize - 0.5) / (JobDetailBottomSheet._expandedSize - 0.5)).clamp(
          0.0,
          1.0,
        );
    final isExpanded = expandProgress > _expandedThreshold;

    return Container(
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: AppRadius.sheetTop,
      ),
      child: Column(
        children: [
          appBar(expandProgress),
          body(expandProgress, isExpanded, context),
          bottomButtonsBar(context, isExpanded),
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
          _saveButton(savedJobsProvider, isSaved: isSaved, show: isExpanded),
          if (isExpanded) const SizedBox(width: AppSizes.space),
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

  Widget _saveButton(
    SavedJobsProvider provider, {
    required bool isSaved,
    required bool show,
  }) {
    return AnimatedContainer(
      duration: _animation,
      width: show ? AppSizes.buttonHeightCompact : 0,
      height: AppSizes.buttonHeightCompact,
      child: show
          ? Material(
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
                  onTap: () => provider.toggleSave(widget.job),
                  child: Center(
                    child: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: isSaved
                          ? context.accentColor
                          : context.textSecondary,
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
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
        child: Text(
          alreadyApplied
              ? 'Başvuruldu ✓'
              : (isExpanded ? 'Başvur' : 'Detayları Gör'),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- Gövde

  Expanded body(double expandProgress, bool isExpanded, BuildContext context) {
    return Expanded(
      child: ListView(
        controller: widget.scrollController,
        padding: AppPadding.primaryHorizontal,
        children: [
          _handleBar(expandProgress),
          _companyRow(expandProgress),
          _title(expandProgress),
          const SizedBox(height: AppSizes.spaceMedium),
          _typeAndPriceRow(expandProgress),
          _sectionTitle('Açıklama', expandProgress),
          _description(expandProgress, isExpanded),
          if (isExpanded && widget.job.duties != null) ...[
            const SizedBox(height: AppSizes.spaceLarge),
            Text('Görevler', style: context.textTheme.titleSmall),
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              widget.job.duties!,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
                height: _descriptionHeightMin,
              ),
            ),
          ],
          if (isExpanded) ...[
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
            ]),
            const SizedBox(height: AppSizes.spaceMedium),
            _buildInfoCard('Gereksinimler', [
              if (widget.job.minAge != null || widget.job.maxAge != null)
                _buildInfoRow(
                  Icons.person,
                  'Yaş Aralığı',
                  '${widget.job.minAge ?? ''}-${widget.job.maxAge ?? ''} yaş',
                ),
              if (widget.job.experienceRequired != null)
                _buildInfoRow(
                  Icons.work,
                  'Deneyim',
                  widget.job.experienceRequired! ? 'Gerekli' : 'Gerekli Değil',
                ),
              if (widget.job.insuranceRequired != null)
                _buildInfoRow(
                  Icons.health_and_safety,
                  'Sigorta',
                  widget.job.insuranceRequired! ? 'Gerekli' : 'Gerekli Değil',
                ),
              if (widget.job.dressCode != null)
                _buildInfoRow(
                  Icons.checkroom,
                  'Kıyafet',
                  widget.job.dressCode!,
                ),
            ]),
          ],
          if (isExpanded &&
              (widget.job.sector != null || widget.job.position != null)) ...[
            const SizedBox(height: AppSizes.spaceMedium),
            _buildInfoCard('İş Bilgileri', [
              if (widget.job.sector != null)
                _buildInfoRow(Icons.business, 'Sektör', widget.job.sector!),
              if (widget.job.position != null)
                _buildInfoRow(Icons.badge, 'Pozisyon', widget.job.position!),
            ]),
          ],
          _locationCard(expandProgress),
          SizedBox(height: context.padding.bottom + AppSizes.navBarClearance),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) =>
      '${value.day}/${value.month}/${value.year} - '
      '${value.hour}:${value.minute.toString().padLeft(2, '0')}';

  /// Sheet kapalıyken görünen tutamaç; açıldıkça kaybolur.
  Widget _handleBar(double expandProgress) {
    return AnimatedOpacity(
      opacity: 1 - expandProgress,
      duration: _animation,
      child: Center(
        child: AnimatedContainer(
          duration: _animation,
          width: AppSizes.sheetHandleWidth,
          height: AppSizes.sheetHandleHeight,
          margin: EdgeInsets.symmetric(
            vertical: AppSizes.spaceSmall * (1 - expandProgress),
          ),
          decoration: BoxDecoration(
            color: context.dividerColor,
            borderRadius: BorderRadius.circular(AppSizes.sheetHandleHeight / 2),
          ),
        ),
      ),
    );
  }

  Widget _companyRow(double expandProgress) {
    final hasDetails = widget.job.companyDetails != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: hasDetails
                ? () => context.push(
                    '/company-detail',
                    extra: widget.job.companyDetails,
                  )
                : null,
            child: Text(
              widget.job.company!,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                fontSize: lerpDouble(
                  _companyFontMin,
                  _companyFontMax,
                  expandProgress,
                ),
                fontWeight: FontWeight.w500,
                color: hasDetails ? context.accentColor : context.textSecondary,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppSizes.spaceSmall),
          child: _categoryChip(expandProgress),
        ),
      ],
    );
  }

  /// Kategori rozeti yalnızca sheet kapalıyken görünür; açıldığında yerini
  /// başlıktaki kategori adına bırakır.
  Widget _categoryChip(double expandProgress) {
    final isHidden = expandProgress > 0.5;

    return AnimatedOpacity(
      opacity: 1 - expandProgress,
      duration: _animation,
      child: AnimatedContainer(
        duration: _animation,
        width: isHidden ? 0 : null,
        padding: isHidden ? EdgeInsets.zero : AppPadding.chip,
        decoration: BoxDecoration(
          color: widget.job.category.color.withValues(alpha: 0.15),
          borderRadius: AppRadius.secondaryCircular,
        ),
        child: isHidden
            ? const SizedBox.shrink()
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.job.category.icon,
                    size: AppSizes.iconSmall,
                    color: widget.job.category.color,
                  ),
                  const SizedBox(width: AppSizes.spaceTiny),
                  Text(
                    widget.job.category.displayName,
                    style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: widget.job.category.color,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _title(double expandProgress) {
    return Text(
      widget.job.title,
      style: context.textTheme.headlineSmall?.copyWith(
        fontSize: lerpDouble(_titleFontMin, _titleFontMax, expandProgress),
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _typeAndPriceRow(double expandProgress) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: AppPadding.chip,
            decoration: BoxDecoration(
              color: context.tileColor,
              borderRadius: AppRadius.secondaryCircular,
            ),
            child: Text(
              widget.job.type.displayName,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
          ),
          Text(
            '${widget.job.price.asPrice}₺',
            style: context.textTheme.displaySmall?.copyWith(
              fontSize: lerpDouble(
                _priceFontMin,
                _priceFontMax,
                expandProgress,
              ),
              fontWeight: FontWeight.w700,
              color: context.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Yalnızca sheet açıkken görünen bölüm başlığı.
  Widget _sectionTitle(String title, double expandProgress) {
    return AnimatedOpacity(
      opacity: expandProgress,
      duration: _animation,
      child: expandProgress > _expandedThreshold
          ? Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSizes.spaceSmall,
              ),
              child: Text(title, style: context.textTheme.titleMedium),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _description(double expandProgress, bool isExpanded) {
    return Text(
      widget.job.description ?? widget.job.subtitle,
      style: context.textTheme.bodyMedium?.copyWith(
        fontSize: lerpDouble(
          _descriptionFontMin,
          _descriptionFontMax,
          expandProgress,
        ),
        color: isExpanded ? context.textSecondary : context.textTertiary,
        height: lerpDouble(
          _descriptionHeightMin,
          _descriptionHeightMax,
          expandProgress,
        ),
      ),
      maxLines: isExpanded ? null : 2,
      overflow: isExpanded ? null : TextOverflow.ellipsis,
    );
  }

  Widget _locationCard(double expandProgress) {
    if (expandProgress <= _expandedThreshold) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: expandProgress,
      duration: _animation,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSizes.spaceLarge),
        child: Container(
          padding: AppPadding.primaryAll,
          decoration: BoxDecoration(
            color: context.tileColor,
            borderRadius: AppRadius.innerCircular,
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: context.accentColor,
                size: AppSizes.icon,
              ),
              const SizedBox(width: AppSizes.space),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Konum', style: context.textTheme.labelMedium),
                    Text(
                      widget.job.address ??
                          '${widget.job.latitude.toStringAsFixed(4)}, '
                              '${widget.job.longitude.toStringAsFixed(4)}',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ Başlık

  AnimatedContainer appBar(double expandProgress) {
    return AnimatedContainer(
      duration: _animation,
      height: lerpDouble(_headerHeightMin, _headerHeightMax, expandProgress),
      child: expandProgress > _expandedThreshold
          ? Container(
              padding: AppPadding.iconButton,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: context.textPrimary,
                    ),
                    onPressed: _closeSheet,
                  ),
                  Opacity(
                    opacity: expandProgress,
                    child: Text(
                      widget.job.category.displayName,
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  // -------------------------------------------------------------- Bilgi kartı

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
        border: Border.all(color: context.dividerColor),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconMedium, color: context.accentColor),
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
