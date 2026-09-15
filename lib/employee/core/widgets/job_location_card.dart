import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// İlan detayındaki konum satırı.
///
/// Ayrı bir widget olmasının sebebi, sheet'in içindeki bir extract method
/// olmaktan çıkarmak: başlık ve alt açıklama [precision]'a göre değişiyor ve bu
/// kararın sheet'in animasyon durumundan bağımsız sınanabilmesi gerekiyor.
class JobLocationCard extends StatelessWidget {
  const JobLocationCard({
    super.key,
    required this.precision,
    required this.label,
    this.directions,
    this.onDirections,
    this.arrival,
  });

  /// Sunucunun konumu bu görüntüleyene hangi kesinlikte verdiği.
  final AddressPrecision precision;

  /// Konumun tek satırlık metni.
  final String label;

  /// İşverenin yazdığı tarif (`components.additionalDirections`); sunucu
  /// bunu yalnızca `EXACT` yanıtta gönderiyor. Yaklaşık konumda çizilmiyor
  /// — açık adresin parçası olduğu için kendi başına bir sızıntı olurdu.
  final String? directions;

  /// "Yol tarifi al" düğmesi (is-koala/koala#188). Verilmezse düğme yok —
  /// ilan kartı (başvuru öncesi) vermiyor, iş detayı yalnız hedef koordinatı
  /// bilirken veriyor. `APPROXIMATE` yanıtta verilse bile **çizilmiyor**:
  /// yuvarlanmış koordinata yol tarifi, olmayan bir adrese götürmek olurdu.
  final VoidCallback? onDirections;

  /// İşin başlangıcı; düğmenin altında "varış hedefi" olarak yazılıyor.
  /// Harita bağlantısına yazılmıyor — bkz. `DirectionsLinks`.
  final DateTime? arrival;

  /// Düğmenin altındaki açıklama: rota toplu taşımayla açılıyor, varış saatini
  /// harita uygulamasında kullanıcı seçiyor (bağlantı onu taşıyamıyor).
  static String directionsNote(DateTime? arrival) => arrival == null
      ? 'Toplu taşıma rotası harita uygulamasında açılır; varış saatini '
            'orada seçebilirsiniz.'
      : 'Toplu taşıma rotası harita uygulamasında açılır. İş başlangıcı '
            '${arrival.asShortDateTime}; varış saatini orada seçebilirsiniz.';

  /// Yaklaşık konumda başlık ve alt açıklama değişiyor.
  ///
  /// Kesinliği ekranda söylemek metni seçmiyor — sunucu `APPROXIMATE` yanıtta
  /// sokağı, binayı ve daireyi zaten silmiş oluyor. Ama kalan ilçe/il metnini
  /// "Konum" diye sunmak, adresin bundan ibaret olduğunu ima ederdi; kullanıcı
  /// "iş burada" diye okur.
  bool get _isApproximate => precision.isApproximate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            AppIcons.location,
            color: context.accentColor,
            size: AppSizes.icon,
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
        style: OutlinedButton.styleFrom(
          foregroundColor: context.accentColor,
          side: BorderSide(color: context.accentColor),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.smallCircular,
          ),
        ),
      ),
    );
  }
}
