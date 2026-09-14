import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/payout.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Hakediş durumunun rozeti; liste satırı ve detay aynı rozeti çiziyor.
class PayoutStatusBadge extends StatelessWidget {
  const PayoutStatusBadge({super.key, required this.status});

  final PayoutStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: context.payoutSurface,
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        status.displayName,
        style: context.textTheme.labelSmall?.copyWith(
          color: colorOf(status),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Color colorOf(PayoutStatus status) => switch (status) {
    PayoutStatus.pending => AppColors.warning,
    PayoutStatus.processing => AppColors.progress,
    PayoutStatus.completed => AppColors.successStrong,
    PayoutStatus.failed => AppColors.danger,
  };
}
