import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// İlan detayındaki (başvuru öncesi) "Ulaşım" kartı (is-koala/koala#197).
///
/// Herkese açık görünümü çiziyor: yöntemler, servis sayısı, durakların
/// ilçe/semt adı ve saati, yol parası tutarı. Plaka, şoför ve tam adres bu
/// görünümde **yok** — sunucu göndermiyor, kart da bilmiyor; koltuk seçimi
/// atama kurulduktan sonra iş detayında.
class JobTransportCard extends StatelessWidget {
  const JobTransportCard({super.key, required this.transport});

  final JobTransport transport;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('job-transport-card'),
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
              Text('Ulaşım', style: context.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            transport.methodsLine,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (transport.shuttleCount > 0) ...[
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              '${transport.shuttleCount} servis',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
          for (final shuttle in transport.shuttles) ...[
            const SizedBox(height: AppSizes.space),
            _shuttle(context, shuttle),
          ],
        ],
      ),
    );
  }

  Widget _shuttle(BuildContext context, PublicShuttle shuttle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${shuttle.name} · ${shuttle.direction.displayName}',
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
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
                    '${stop.placeLabel} · '
                    '${stop.scheduledAt.toLocal().asShortTime}',
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
