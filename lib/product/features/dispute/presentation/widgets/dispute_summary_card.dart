import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/jobs/models/dispute.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/dispute/presentation/widgets/dispute_card.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/status_badge.dart';

/// İş detayındaki uyuşmazlık özeti (#215); en yeni uyuşmazlığı gösteriyor (aynı
/// anda tek açık olabilir).
class DisputeSummaryCard extends StatelessWidget {
  const DisputeSummaryCard({
    super.key,
    required this.dispute,
    required this.onOpen,
  });

  final Dispute dispute;

  final VoidCallback onOpen;

  static const int _reasonMaxLines = 2;

  @override
  Widget build(BuildContext context) {
    final reason = dispute.reason;
    // Açıkta asıl eylem kanıt eklemek, sonuçlanmışta okumak.
    final label = dispute.isOpen
        ? 'Kanıt ekle ya da görüntüle'
        : 'Kanıtları görüntüle';

    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: InkWell(
        key: const ValueKey('dispute-summary'),
        borderRadius: AppRadius.innerCircular,
        onTap: onOpen,
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sorun Bildirimi',
                      style: context.textTheme.titleSmall,
                    ),
                  ),
                  StatusBadge(
                    dispute.status.displayName,
                    color: dispute.status.color,
                  ),
                ],
              ),
              if (reason != null && reason.isNotEmpty) ...[
                const SizedBox(height: AppSizes.spaceSmall),
                Text(
                  reason,
                  maxLines: _reasonMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.space),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AppIcon(
                    AppIcons.arrowRight,
                    size: AppSizes.iconMedium,
                    color: context.accentColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
