import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/formatters/turkish_money_formatter.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// İptal edilmiş işin kartı: kim, ne zaman, neden ve para ne oldu.
///
/// `CancellationDto` şimdiye kadar hiç okunmuyordu (is-koala/koala#177);
/// iş iptal olunca kullanıcı yalnızca kırmızı bir "İptal Edildi" görüyordu.
/// Kesinti çalışanın kendi iptalinde çıkmıyor; işverenin geç iptalinde
/// çıkabiliyor ve iade işverene gidiyor — kart bunu rakamla söylüyor.
class CancellationCard extends StatelessWidget {
  const CancellationCard({super.key, required this.cancellation});

  final Cancellation cancellation;

  /// İptal tutarları TRY; `CancellationDto` para birimi taşımıyor.
  static const String _currency = 'TRY';

  @override
  Widget build(BuildContext context) {
    final reason = cancellation.reason?.trim();
    final cancelledAt = cancellation.cancelledAt;

    return Container(
      key: const ValueKey('cancellation-card'),
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(
                AppIcons.cancelCircle,
                size: AppSizes.iconMedium,
                color: AppColors.danger,
              ),
              const SizedBox(width: AppSizes.spaceSmall),
              Expanded(
                child: Text(
                  '${cancellation.cancelledByParty.displayName} iptal etti',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (cancelledAt != null) ...[
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              cancelledAt.toLocal().asShortDateTime,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              '"$reason"',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            cancellation.hasFee
                ? '%${cancellation.feePercent} kesinti uygulandı '
                      '(${TurkishMoneyFormatter.format(cancellation.feeAmount, _currency)}); '
                      '${TurkishMoneyFormatter.format(cancellation.refundAmount, _currency)} '
                      'işverene iade edildi.'
                : 'Kesinti uygulanmadı; ücret işverene iade edildi.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
