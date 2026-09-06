import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/b_payment_attempt.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/formatters/turkish_money_formatter.dart';

/// Bir atamanın ödeme denemelerini kendi yükleme, hata ve boş durumlarıyla
/// gösteren salt-okunur bölüm.
class BPaymentAttemptsSection extends StatelessWidget {
  const BPaymentAttemptsSection({
    super.key,
    required this.attempts,
    required this.isLoading,
    required this.onRetry,
    this.errorMessage,
  });

  final List<BPaymentAttempt> attempts;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  static const _failedPaymentMessage =
      'Ödeme tamamlanamadı. Lütfen tekrar dene.';

  @override
  Widget build(BuildContext context) {
    if (isLoading && attempts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = errorMessage;
    if (error != null && attempts.isEmpty) {
      return _panel(
        context,
        child: Column(
          children: [
            Text(
              error,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceSmall),
            TextButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
          ],
        ),
      );
    }

    if (attempts.isEmpty) {
      return _panel(
        context,
        child: Text(
          'Henüz ödeme denemesi yok.',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.textSecondary,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < attempts.length; index++) ...[
          _attemptCard(context, attempts[index]),
          if (index != attempts.length - 1)
            const SizedBox(height: AppSizes.spaceSmall),
        ],
      ],
    );
  }

  Widget _attemptCard(BuildContext context, BPaymentAttempt attempt) {
    final total = attempt.pricing?.employerTotal ?? attempt.totalCharged;

    return _panel(
      context,
      padding: AppPadding.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusBadge(context, attempt.status),
              const Spacer(),
              Text(
                TurkishMoneyFormatter.format(total, attempt.currency),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            attempt.createdAt.toLocal().asShortDateTime,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textTertiary,
            ),
          ),
          if (attempt.status == BPaymentAttemptStatus.failed) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              _failedPaymentMessage,
              style: context.textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(BuildContext context, BPaymentAttemptStatus status) {
    final color = switch (status) {
      BPaymentAttemptStatus.initiated => AppColors.warning,
      BPaymentAttemptStatus.inReview => AppColors.progress,
      BPaymentAttemptStatus.succeeded => AppColors.successStrong,
      BPaymentAttemptStatus.failed => AppColors.danger,
    };

    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: context.payoutSurface,
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        status.displayName,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _panel(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = AppPadding.primaryAll,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: child,
    );
  }
}
