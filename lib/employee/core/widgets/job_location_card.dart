import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

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
  });

  /// Sunucunun konumu bu görüntüleyene hangi kesinlikte verdiği.
  final AddressPrecision precision;

  /// Konumun tek satırlık metni.
  final String label;

  /// Yaklaşık konumda başlık ve alt açıklama değişiyor.
  ///
  /// Kesinliği ekranda söylemek metni seçmiyor — sunucu `APPROXIMATE` yanıtta
  /// sokağı, binayı ve daireyi zaten silmiş oluyor. Ama kalan ilçe/il metnini
  /// "Konum" diye sunmak, adresin bundan ibaret olduğunu ima ederdi; kullanıcı
  /// "iş burada" diye okur.
  bool get _isApproximate => precision == AddressPrecision.approximate;

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
          Icon(
            Icons.location_on,
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
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
