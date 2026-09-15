import 'package:flutter/material.dart';
import 'package:koala/business/features/transport/models/transport_plan_draft.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// İşverenin ulaşım planı özeti (is-koala/koala#197).
///
/// İlan oluşturma formunda (taslak) ve ilan detayında (sunucudaki plan,
/// [TransportPlanDraft.fromPlan] ile) aynı kart: yöntemler, yol parası,
/// servisler — plaka, doluluk (`seatsTaken/capacity`) ve duraklar saatiyle.
/// İşveren görünümü olduğu için plaka her serviste yazılıyor.
class BTransportPlanSummary extends StatelessWidget {
  const BTransportPlanSummary({
    super.key,
    required this.plan,
    this.onEdit,
    this.onRemove,
  });

  final TransportPlanDraft plan;

  /// "Düzenle" düğmesi; verilmezse yok.
  final VoidCallback? onEdit;

  /// "Kaldır" düğmesi (yalnız ilan oluşturma taslağında).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final notes = plan.notes.trim();

    return Container(
      key: const ValueKey('b-transport-summary'),
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                AppIcons.bus,
                size: AppSizes.iconMedium,
                color: context.accentColor,
              ),
              const SizedBox(width: AppSizes.spaceSmall),
              Expanded(
                child: Text(
                  plan.methodsLine,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (plan.hasCashAllowance && plan.allowanceNote.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.spaceTiny),
              child: Text(
                plan.allowanceNote.trim(),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ),
          for (final shuttle in plan.shuttles) ...[
            const SizedBox(height: AppSizes.space),
            _shuttle(context, shuttle),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: AppSizes.space),
            Text(
              'Not: $notes',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
          if (onEdit != null || onRemove != null) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onRemove != null)
                  TextButton(
                    key: const ValueKey('b-transport-remove'),
                    onPressed: onRemove,
                    child: const Text('Kaldır'),
                  ),
                if (onEdit != null)
                  TextButton.icon(
                    key: const ValueKey('b-transport-edit'),
                    onPressed: onEdit,
                    icon: AppIcon(
                      AppIcons.edit,
                      size: AppSizes.iconSmall,
                      color: context.accentColor,
                    ),
                    label: const Text('Düzenle'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _shuttle(BuildContext context, ShuttleDraft shuttle) {
    final capacity = shuttle.capacity;
    final occupancy = capacity == null
        ? null
        : '${shuttle.seatsTaken}/$capacity dolu';
    final details = [
      if (shuttle.plate.trim().isNotEmpty) shuttle.plate.trim(),
      ?occupancy,
      if (shuttle.driverName.trim().isNotEmpty) shuttle.driverName.trim(),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${shuttle.name.trim().isEmpty ? 'Servis' : shuttle.name.trim()} · '
          '${shuttle.direction.displayName}',
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        if (details.isNotEmpty)
          Text(
            details,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
        for (final stop in shuttle.stops)
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.spaceTiny),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(
                  AppIcons.location,
                  size: AppSizes.iconSmall,
                  color: context.textTertiary,
                ),
                const SizedBox(width: AppSizes.spaceTiny),
                Expanded(
                  child: Text(
                    '${stop.displayName} · '
                    '${stop.scheduledAt?.asShortTime ?? '--:--'}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
