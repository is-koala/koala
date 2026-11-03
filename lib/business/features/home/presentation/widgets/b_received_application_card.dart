import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/received_application.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/status_badge.dart';

/// Gelen kutusundaki tek başvuru kartı.
///
/// Kartın kendisi başvuruyu **incelemeye** götürüyor ([onOpen]: ilanın karar
/// ekranı, kabul/ret orada); adayın profili ayrı bir düğme ([onOpenProfile]).
/// Gelen kutusu karar vermiyor, o yüzden kartta kabul/ret düğmesi yok.
class BReceivedApplicationCard extends StatelessWidget {
  const BReceivedApplicationCard({
    super.key,
    required this.application,
    required this.onOpen,
    required this.onOpenProfile,
  });

  final ReceivedApplication application;

  /// Karta dokunuş: başvurunun geldiği ilanın karar ekranı.
  final VoidCallback onOpen;

  /// "Adayın profili" düğmesi.
  final VoidCallback onOpenProfile;

  /// Satırdaki avatar; başvuran kartıyla aynı ölçek.
  static const double _avatarSize = 48;

  /// Başvuru notunun en fazla görünen satırı; tamamı karar ekranında.
  static const int _notesMaxLines = 2;

  @override
  Widget build(BuildContext context) {
    final company = application.companyName;
    final notes = application.notes;

    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: InkWell(
        borderRadius: AppRadius.innerCircular,
        onTap: onOpen,
        child: Padding(
          padding: AppPadding.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatar(
                    imageUrl: application.applicant.profilePictureUrl,
                    size: _avatarSize,
                  ),
                  const SizedBox(width: AppSizes.space),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.fullName.isEmpty
                              ? 'Adı paylaşılmadı'
                              : application.fullName,
                          style: context.textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSizes.spaceTiny),
                        Text(
                          application.postingTitle,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                        if (company != null) ...[
                          const SizedBox(height: AppSizes.smallGap),
                          Text(
                            company,
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceSmall),
                  StatusBadge(
                    application.status.inboxLabel,
                    color: application.status.inboxColor(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceSmall),
              _dates(context),
              if (notes != null) ...[
                const SizedBox(height: AppSizes.spaceSmall),
                Text(
                  notes,
                  maxLines: _notesMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.spaceSmall),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: ValueKey('application-profile-${application.id}'),
                  onPressed: onOpenProfile,
                  style: TextButton.styleFrom(
                    padding: AppPadding.badge,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Adayın profili'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Başvuru tarihi, varsa yanıt tarihi ve kapanmış ilan rozeti.
  Widget _dates(BuildContext context) {
    final style = context.textTheme.labelMedium?.copyWith(
      color: context.textTertiary,
    );
    final appliedAt = application.applicationDateTime;
    final answeredAt = application.answeredDateTime;

    return Wrap(
      spacing: AppSizes.space,
      runSpacing: AppSizes.spaceTiny,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (appliedAt != null)
          Text('Başvuru: ${appliedAt.toLocal().asShortDate}', style: style),
        if (answeredAt != null)
          Text(
            '${application.status.answerLabel}: '
            '${answeredAt.toLocal().asShortDate}',
            key: ValueKey('application-answered-${application.id}'),
            style: style,
          ),
        if (application.isJobClosed)
          StatusBadge(
            application.jobStatus.inboxLabel,
            color: context.textTertiary,
          ),
      ],
    );
  }
}

/// Gelen kutusunun durum dili. Süzgeç çipleri de aynı sözcükleri kullanıyor.
extension InboxApplicationStatus on ApplicationStatus {
  /// Kartın rozeti.
  String get inboxLabel => switch (this) {
    ApplicationStatus.applied => 'Bekliyor',
    ApplicationStatus.accepted => 'Kabul edildi',
    ApplicationStatus.rejected => 'Reddedildi',
    ApplicationStatus.withdrawn => 'Geri çekildi',
    ApplicationStatus.unknown => 'Bilinmiyor',
  };

  /// Süzgeç çipinin adı.
  String get inboxFilterLabel => switch (this) {
    ApplicationStatus.applied => 'Bekleyenler',
    ApplicationStatus.accepted => 'Kabul edilenler',
    ApplicationStatus.rejected => 'Reddedilenler',
    ApplicationStatus.withdrawn => 'Geri çekilenler',
    ApplicationStatus.unknown => 'Bilinmiyor',
  };

  /// Yanıt tarihinin etiketi. Geri çekme yanıt değil başvuranın kendi kararı
  /// ve sunucu onda `answeredDateTime` yazmıyor; yine de gelirse yanıt
  /// sayılmıyor, "Yanıt" demek yanlış olurdu.
  String get answerLabel => switch (this) {
    ApplicationStatus.accepted => 'Kabul',
    ApplicationStatus.rejected => 'Red',
    _ => 'Yanıt',
  };

  /// Rozet rengi. Bekleyen, çalışanın "başvuru bekliyor" bölümüyle aynı mor;
  /// tanınmayan ve geri çekilen durum hiçbir eylem önermediği için nötr.
  Color inboxColor(BuildContext context) => switch (this) {
    ApplicationStatus.applied => AppColors.pending,
    ApplicationStatus.accepted => AppColors.successStrong,
    ApplicationStatus.rejected => AppColors.danger,
    ApplicationStatus.withdrawn ||
    ApplicationStatus.unknown => context.textTertiary,
  };
}

extension InboxJobStatus on JobStatus {
  /// Kapanmış ilanın rozeti; açık ilanda çizilmiyor.
  String get inboxLabel => switch (this) {
    JobStatus.open => 'İlan açık',
    JobStatus.closed => 'İlan kapalı',
    JobStatus.cancelled => 'İlan iptal edildi',
  };
}
