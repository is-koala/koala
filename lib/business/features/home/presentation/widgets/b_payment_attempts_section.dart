import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/b_payment_attempt.dart';
import 'package:koala/product/models/pricing_breakdown.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/formatters/turkish_money_formatter.dart';
import 'package:koala/product/formatters/financial_failure_message.dart';

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
            _timestamps(attempt),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textTertiary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          Text(
            _breakdown(attempt),
            key: ValueKey('payment-attempt-breakdown-${attempt.id}'),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
          if (attempt.status == BPaymentAttemptStatus.failed) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              FinancialFailureMessage.payment(attempt.failureReason),
              style: context.textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Başlatılma ve — sunucu göndermişse — tamamlanma anı.
  ///
  /// `completedAt` başarılı denemede tahsilatın kesinleştiği, başarısızda
  /// sonucun öğrenildiği an; hâlâ süren denemede boş.
  static String _timestamps(BPaymentAttempt attempt) {
    final started = attempt.createdAt.toLocal().asShortDateTime;
    final completed = attempt.completedAt;
    if (completed == null) return started;
    return '$started · Tamamlandı: ${completed.toLocal().asShortDateTime}';
  }

  /// Denemenin dökümü: çalışan ücreti ve komisyon. Backend dizeleri olduğu
  /// gibi biçimleniyor, toplam ayrıca hesaplanmıyor — o zaten üst satırda.
  static String _breakdown(BPaymentAttempt attempt) {
    final payout = TurkishMoneyFormatter.format(
      attempt.workerPayout,
      attempt.currency,
    );
    final commission = TurkishMoneyFormatter.format(
      attempt.commissionAmount,
      attempt.currency,
    );
    final rate = PricingBreakdown.percentLabel(attempt.commissionRate);
    return 'Çalışan ücreti: $payout · Komisyon: $commission (%$rate)';
  }

  Widget _statusBadge(BuildContext context, BPaymentAttemptStatus status) {
    final color = switch (status) {
      BPaymentAttemptStatus.initiated => AppColors.warning,
      BPaymentAttemptStatus.inReview => AppColors.progress,
      BPaymentAttemptStatus.verifyPending => AppColors.progress,
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
