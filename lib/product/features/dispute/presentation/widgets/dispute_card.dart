import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/dispute.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/features/dispute/models/dispute_evidence.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/features/dispute/presentation/providers/dispute_provider.dart';
import 'package:koala/product/features/dispute/presentation/widgets/evidence_tile.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/status_badge.dart';

/// Uyuşmazlığın rozet rengi: açık bekleyen turuncu, incelenen mavi,
/// sonuçlanan yeşil.
extension DisputeStatusStyle on DisputeStatus {
  Color get color => switch (this) {
    DisputeStatus.open => AppColors.warning,
    DisputeStatus.underReview => AppColors.info,
    DisputeStatus.resolved => AppColors.successStrong,
  };
}

/// Tek bir uyuşmazlık: durum, gerekçe, sonuç ve kanıtlar.
///
/// Kendi başına bir istek atmıyor; sayfa [DisputeCase]'i ve eylemleri veriyor.
/// Kanıt ekleme düğmesi yalnız [DisputeCase.canAttach] iken çiziliyor; neden
/// çizilmediğini ([DisputeCase.isLimitReached], sonuçlanmış) satır söylüyor —
/// sessizce kaybolan bir düğme "bozuk" gibi okunur.
class DisputeCard extends StatelessWidget {
  const DisputeCard({
    super.key,
    required this.entry,
    required this.upload,
    required this.downloadingId,
    required this.onAttach,
    required this.onDownload,
    required this.onRetryEvidence,
  });

  final DisputeCase entry;

  /// Bu uyuşmazlığa giden yükleme; başka uyuşmazlığınki ya da yok ise `null`.
  final EvidenceUpload? upload;

  /// Süren indirmenin kanıt kimliği (başka satır kilitli kalıyor).
  final String? downloadingId;

  final VoidCallback onAttach;
  final ValueChanged<DisputeEvidence> onDownload;
  final VoidCallback onRetryEvidence;

  @override
  Widget build(BuildContext context) {
    final dispute = entry.dispute;
    final openedAt = dispute.createdAt;
    final opener = dispute.openedBy?.fullName ?? '';
    final reason = dispute.reason;
    final note = dispute.resolutionNote;
    final resolution = dispute.resolution;

    return Container(
      key: ValueKey('dispute-${dispute.id}'),
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                dispute.status.displayName,
                color: dispute.status.color,
              ),
              const Spacer(),
              if (openedAt != null)
                Text(
                  openedAt.toLocal().asShortDate,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
            ],
          ),
          if (opener.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              'Bildiren: $opener',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ],
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            Text(reason, style: context.textTheme.bodyMedium),
          ],
          if (resolution != null) ...[
            const SizedBox(height: AppSizes.space),
            Text(
              resolution.displayName,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spaceTiny),
              Text(
                note,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSizes.spaceMedium),
          _evidenceHeader(context),
          const SizedBox(height: AppSizes.spaceSmall),
          ..._evidenceBody(context),
          if (upload != null) ...[
            const SizedBox(height: AppSizes.space),
            _uploadStrip(context, upload!),
          ],
          ..._attachSection(context),
        ],
      ),
    );
  }

  Widget _evidenceHeader(BuildContext context) {
    final count = entry.isEvidenceKnown
        ? ' (${entry.evidence.length}/${DisputeEvidencePolicy.maxPerDispute})'
        : '';
    return Text('Kanıtlar$count', style: context.textTheme.titleSmall);
  }

  List<Widget> _evidenceBody(BuildContext context) {
    if (entry.isEvidenceLoading) {
      return const [
        Padding(
          padding: AppPadding.primaryVertical,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final error = entry.evidenceError;
    if (error != null && entry.evidence.isEmpty) {
      return [
        Text(error, style: context.textTheme.bodyMedium),
        const SizedBox(height: AppSizes.spaceSmall),
        OutlinedButton(
          key: ValueKey('evidence-retry-${entry.dispute.id}'),
          onPressed: onRetryEvidence,
          child: const Text('Tekrar Dene'),
        ),
      ];
    }

    if (entry.evidence.isEmpty) {
      return [
        Text(
          'Henüz kanıt eklenmedi.',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.textTertiary,
          ),
        ),
      ];
    }

    return [
      for (final evidence in entry.evidence) ...[
        EvidenceTile(
          key: ValueKey('evidence-${evidence.id}'),
          evidence: evidence,
          isDownloading: downloadingId == evidence.id,
          isBusy: downloadingId != null,
          onDownload: () => onDownload(evidence),
        ),
        const SizedBox(height: AppSizes.spaceSmall),
      ],
      if (error != null)
        Text(
          error,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.textTertiary,
          ),
        ),
    ];
  }

  Widget _uploadStrip(BuildContext context, EvidenceUpload upload) {
    final percent = upload.fraction;
    return Column(
      key: const ValueKey('evidence-upload'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          percent == null
              ? 'Yükleniyor · ${upload.fileName}'
              : 'Yükleniyor · %${(percent * 100).round()} · ${upload.fileName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.spaceTiny),
        LinearProgressIndicator(
          key: const ValueKey('evidence-upload-bar'),
          value: percent,
        ),
      ],
    );
  }

  /// Ekleme düğmesi ve uyarıları.
  List<Widget> _attachSection(BuildContext context) {
    final style = context.textTheme.labelMedium?.copyWith(
      color: context.textTertiary,
    );

    if (!entry.dispute.isOpen) {
      return [
        const SizedBox(height: AppSizes.space),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(
              AppIcons.info,
              size: AppSizes.iconSmall,
              color: context.textTertiary,
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            Expanded(
              child: Text(
                'Uyuşmazlık sonuçlandığı için yeni kanıt eklenemez; mevcut '
                'dosyaları indirebilirsiniz.',
                style: style,
              ),
            ),
          ],
        ),
      ];
    }

    if (entry.isLimitReached) {
      return [
        const SizedBox(height: AppSizes.space),
        Text(
          'Kanıt sınırına ulaşıldı: bir uyuşmazlığa iki tarafın toplamı en '
          'fazla ${DisputeEvidencePolicy.maxPerDispute} dosya eklenebilir.',
          key: const ValueKey('evidence-limit-note'),
          style: style,
        ),
      ];
    }

    if (!entry.canAttach) return const [];

    return [
      const SizedBox(height: AppSizes.space),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: ValueKey('evidence-add-${entry.dispute.id}'),
          onPressed: upload == null ? onAttach : null,
          icon: AppIcon(
            AppIcons.plus,
            size: AppSizes.iconMedium,
            color: upload == null ? context.accentColor : context.textTertiary,
          ),
          label: const Text('Kanıt Ekle'),
        ),
      ),
      const SizedBox(height: AppSizes.spaceSmall),
      Text(
        'PDF, PNG, JPG veya WEBP · dosya başına en fazla 10 MB · her '
        'yüklemede bir dosya.',
        style: style,
      ),
      const SizedBox(height: AppSizes.spaceTiny),
      // Metadata silinmiyor (EvidencePicker): kullanıcı neyin gittiğini
      // bilmeli, karşı taraf da dosyayı indirebiliyor.
      Text(
        'Fotoğraflar çekim saati ve — kamerada konum açıksa — konum '
        'bilgisiyle birlikte gönderilir. Karşı taraf ve Koala destek ekibi '
        'dosyayı görebilir.',
        key: const ValueKey('evidence-metadata-note'),
        style: style,
      ),
    ];
  }
}
