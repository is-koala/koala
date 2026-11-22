import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// İlan detayının konum satırı; başlık ve açıklama [precision]'a göre değiştiği
/// için sheet'ten bağımsız sınanabilsin diye ayrı.
class JobLocationCard extends StatelessWidget {
  const JobLocationCard({
    super.key,
    required this.precision,
    required this.label,
    this.directions,
    this.onDirections,
    this.arrival,
    this.plain = false,
  });

  /// `true` ise kart zemini ve iç boşluk yok.
  final bool plain;

  final AddressPrecision precision;

  final String label;

  /// İşverenin tarifi; yalnız `EXACT` yanıtta geliyor. Yaklaşıkta çizilmez,
  /// açık adresin parçası.
  final String? directions;

  /// "Yol tarifi al" (#188). `APPROXIMATE`'te verilse bile **çizilmez**:
  /// yuvarlanmış koordinata yol tarifi olmayan bir adrese götürür.
  final VoidCallback? onDirections;

  /// Düğmenin altında yazılır; bağlantıya yazılmaz.
  final DateTime? arrival;

  static String directionsNote(DateTime? arrival) => arrival == null
      ? 'Toplu taşıma rotası harita uygulamasında açılır; varış saatini '
            'orada seçebilirsiniz.'
      : 'Toplu taşıma rotası harita uygulamasında açılır. İş başlangıcı '
            '${arrival.asShortDateTime}; varış saatini orada seçebilirsiniz.';

  /// Yaklaşık konumda başlık değişir: ilçe/il'i "Konum" diye sunmak adresin
  /// bundan ibaret olduğunu ima ederdi.
  bool get _isApproximate => precision.isApproximate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: plain ? EdgeInsets.zero : AppPadding.primaryAll,
      decoration: plain
          ? null
          : BoxDecoration(
              color: context.tileColor,
              borderRadius: AppRadius.innerCircular,
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            AppIcons.location,
            color: context.accentColor,
            size: plain ? AppSizes.iconMedium : AppSizes.icon,
          ),
          const SizedBox(width: AppSizes.space),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isApproximate ? 'Yaklaşık konum' : 'Konum',
                  style: context.textTheme.labelMedium,
                ),
                Text(
                  label,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_isApproximate) ...[
                  const SizedBox(height: AppSizes.spaceSmall),
                  Text(
                    'Tam adres, başvurun kabul edilip atama kurulduğunda '
                    'paylaşılır.',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ] else ...[
                  if (directions != null && directions!.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.spaceSmall),
                    Text(
                      'Tarif: ${directions!}',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                  if (onDirections != null) ...[
                    const SizedBox(height: AppSizes.spaceSmall),
                    _directionsButton(context),
                    const SizedBox(height: AppSizes.spaceTiny),
                    Text(
                      directionsNote(arrival),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _directionsButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const ValueKey('job-location-directions'),
        onPressed: onDirections,
        icon: AppIcon(
          AppIcons.route,
          size: AppSizes.iconSmall,
          color: context.accentColor,
        ),
        label: const Text('Yol tarifi al'),
        style: context.accentOutlinedButtonStyle,
      ),
    );
  }
}
