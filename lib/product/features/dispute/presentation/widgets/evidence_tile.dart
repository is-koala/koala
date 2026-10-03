import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/features/dispute/models/dispute_evidence.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Kanıt listesindeki tek dosya: ad, tür, boyut, yükleyen ve tarih.
///
/// Dokunmak dosyayı indirir ([onDownload]); dosya uygulamada **çizilmiyor** —
/// sunucu `attachment` olarak servis ediyor ve imzalı adres üç dakika
/// geçerli, önizleme için saklanamaz.
class EvidenceTile extends StatelessWidget {
  const EvidenceTile({
    super.key,
    required this.evidence,
    required this.onDownload,
    this.isDownloading = false,
    this.isBusy = false,
  });

  final DisputeEvidence evidence;

  /// Dokunuş: indirme isteği.
  final VoidCallback onDownload;

  /// Bu satırın indirmesi sürüyor.
  final bool isDownloading;

  /// Başka bir indirme sürüyor; bu satır kilitli.
  final bool isBusy;

  /// Tür ikonunun kutusu.
  static const double _iconBox = 40;

  /// Dosya adının görünen en fazla satırı.
  static const int _nameMaxLines = 2;

  @override
  Widget build(BuildContext context) {
    final createdAt = evidence.createdAt;
    final meta = [
      evidence.uploaderName,
      formatFileSize(evidence.fileSize),
      if (createdAt != null) createdAt.toLocal().asShortDate,
    ].join(' · ');

    return Material(
      color: context.backgroundColor,
      borderRadius: AppRadius.innerCircular,
      child: InkWell(
        borderRadius: AppRadius.innerCircular,
        onTap: isDownloading || isBusy ? null : onDownload,
        child: Padding(
          padding: AppPadding.card,
          child: Row(
            children: [
              Container(
                width: _iconBox,
                height: _iconBox,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(
                    alpha: AppColors.surfaceTintAlpha,
                  ),
                  borderRadius: AppRadius.innerCircular,
                ),
                child: AppIcon(
                  _iconFor(evidence.kind),
                  size: AppSizes.iconMedium,
                  color: context.accentColor,
                ),
              ),
              const SizedBox(width: AppSizes.space),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evidence.fileName,
                      maxLines: _nameMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSizes.smallGap),
                    Text(
                      meta,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.spaceSmall),
              if (isDownloading)
                const SizedBox(
                  width: AppSizes.iconMedium,
                  height: AppSizes.iconMedium,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                AppIcon(
                  AppIcons.download,
                  size: AppSizes.iconMedium,
                  color: isBusy ? context.textTertiary : context.accentColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static AppIconData _iconFor(EvidenceKind kind) => switch (kind) {
    EvidenceKind.image => AppIcons.gallery,
    EvidenceKind.pdf => AppIcons.fileText,
    EvidenceKind.other => AppIcons.file,
  };
}
