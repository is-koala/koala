import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koala/employee/features/jobs/models/payout.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/payout_status_badge.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/formatters/financial_failure_message.dart';
import 'package:koala/product/formatters/turkish_money_formatter.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';

/// Bir hakedişin detayı (is-koala/koala#189): iş, şirket, çıkış ve mutabakat
/// zamanı, gittiği hesabın maskeli IBAN'ı ve sağlayıcı referansı.
///
/// Kesin ifade yalnız `COMPLETED`'da: mutabakat satırı o zaman dolu, diğer
/// durumlarda `—`. IBAN sunucudan maskeli geliyor ve hesap silinmişse hiç
/// gelmiyor; not bunu söylüyor. Referans kopyalanabilir — destek yazışmasında
/// istenen şey o.
class PayoutDetailSheet extends StatelessWidget {
  const PayoutDetailSheet({
    super.key,
    required this.payout,
    required this.onOpenWork,
    this.jobTitle,
  });

  final Payout payout;

  /// Hakedişin ait olduğu işin detayını açar; sayfa üstlenir, sheet önce
  /// kendini kapatır.
  final VoidCallback onOpenWork;

  /// İş başlığı yedeği: eski sunucu `jobTitle` göndermiyorsa atama
  /// listesinden gelen ad.
  final String? jobTitle;

  /// Bilinmeyen değerin yerine yazılan işaret.
  static const String _unknown = '—';

  /// IBAN satırının altındaki açıklama.
  static const String ibanNote =
      'Bu hesap silinmişse IBAN görünmez; hakediş çıkış anındaki hesaba '
      'gönderildi.';

  static Future<void> show(
    BuildContext context, {
    required Payout payout,
    required VoidCallback onOpenWork,
    String? jobTitle,
  }) {
    return AppBottomSheet.show<void>(
      context,
      builder: (_) => PayoutDetailSheet(
        payout: payout,
        onOpenWork: onOpenWork,
        jobTitle: jobTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settledAt = payout.settledAtOrCompleted;
    final reference = payout.providerReference;

    return AppBottomSheet(
      title: 'Hakediş Detayı',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _amountHeader(context),
            const SizedBox(height: AppSizes.spaceMedium),
            _row(context, 'İş', payout.jobTitle ?? jobTitle ?? _unknown),
            _row(context, 'Şirket', payout.companyName ?? _unknown),
            _row(
              context,
              'Hesap',
              payout.maskedIban ?? _unknown,
              valueKey: const ValueKey('payout-detail-iban'),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
              child: Text(
                ibanNote,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.textTertiary,
                ),
              ),
            ),
            _row(
              context,
              'Çıkışa alındı',
              payout.releasedAtOrCreated.toLocal().asShortDateTime,
            ),
            _row(
              context,
              'Sağlayıcı referansı',
              reference ?? _unknown,
              valueKey: const ValueKey('payout-detail-reference'),
              trailing: reference == null
                  ? null
                  : IconButton(
                      key: const ValueKey('payout-detail-copy'),
                      tooltip: 'Referansı kopyala',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copy(context, reference),
                      icon: AppIcon(
                        AppIcons.copy,
                        size: AppSizes.iconSmall,
                        color: context.accentColor,
                      ),
                    ),
            ),
            _row(
              context,
              'Mutabakat',
              settledAt?.toLocal().asShortDateTime ?? _unknown,
              valueKey: const ValueKey('payout-detail-settled'),
            ),
            if (payout.status == PayoutStatus.failed) ...[
              const SizedBox(height: AppSizes.spaceSmall),
              Text(
                FinancialFailureMessage.payout(payout.failureReason),
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],
            const SizedBox(height: AppSizes.spaceMedium),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('payout-detail-open-work'),
                onPressed: () {
                  Navigator.pop(context);
                  onOpenWork();
                },
                icon: AppIcon(
                  AppIcons.work,
                  size: AppSizes.iconSmall,
                  color: context.accentColor,
                ),
                label: const Text('İş detayını aç'),
                style: context.accentOutlinedButtonStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                TurkishMoneyFormatter.format(payout.amount, payout.currency),
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            PayoutStatusBadge(status: payout.status),
          ],
        ),
        const SizedBox(height: AppSizes.spaceTiny),
        Text(
          payout.status.description,
          key: const ValueKey('payout-detail-status'),
          style: context.textTheme.bodySmall?.copyWith(
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Key? valueKey,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Flexible(
            flex: 2,
            child: Text(
              value,
              key: valueKey,
              textAlign: TextAlign.end,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String reference) async {
    await Clipboard.setData(ClipboardData(text: reference));
    if (!context.mounted) return;
    AppToast.success(context, 'Referans kopyalandı');
  }
}
