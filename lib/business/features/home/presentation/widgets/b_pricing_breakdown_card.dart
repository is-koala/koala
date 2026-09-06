import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/b_pricing_breakdown.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Backend fiyat snapshot'ını hesap yapmadan gösteren ortak kutu.
class BPricingBreakdownCard extends StatelessWidget {
  const BPricingBreakdownCard({super.key, required this.breakdown});

  final BPricingBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.payoutSurface,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        children: [
          _row(context, 'Çalışana ödenecek', breakdown.workerPayout),
          const SizedBox(height: AppSizes.spaceSmall),
          _row(
            context,
            'Koala hizmet bedeli (%${_percent(breakdown.serviceFeeRate)})',
            breakdown.serviceFeeAmount,
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Divider(color: context.dividerColor),
          const SizedBox(height: AppSizes.spaceSmall),
          _row(
            context,
            'Toplam ödeyeceğin',
            breakdown.employerTotal,
            emphasized: true,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String amount, {
    bool emphasized = false,
  }) {
    final style = emphasized
        ? context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : context.textTheme.bodyMedium;

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: AppSizes.spaceSmall),
        Text(amount, style: style),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          breakdown.currency == 'TRY' ? '₺' : breakdown.currency,
          style: style,
        ),
      ],
    );
  }

  /// Backend'in oran dizesini yalnızca yüzde etiketi için ondalık noktası iki
  /// basamak sağa kaydırarak biçimler. Ücret veya hizmet bedeli hesaplamaz.
  static String _percent(String rate) {
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$').firstMatch(rate);
    if (match == null) return rate.replaceAll('.', ',');

    final sign = match.group(1) ?? '';
    final whole = match.group(2)!;
    final fraction = match.group(3) ?? '';
    var digits = '$whole$fraction';
    var decimalPosition = whole.length + 2;

    if (decimalPosition >= digits.length) {
      digits = digits.padRight(decimalPosition, '0');
    } else if (decimalPosition <= 0) {
      digits = digits.padLeft(digits.length - decimalPosition, '0');
      decimalPosition = 1;
    }

    var percentWhole = digits.substring(0, decimalPosition);
    var percentFraction = digits.substring(decimalPosition);
    percentWhole = percentWhole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    percentFraction = percentFraction.replaceFirst(RegExp(r'0+$'), '');

    return percentFraction.isEmpty
        ? '$sign$percentWhole'
        : '$sign$percentWhole,$percentFraction';
  }
}
