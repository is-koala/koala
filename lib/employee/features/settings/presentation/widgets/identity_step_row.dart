import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Numaralı bir yönerge satırı: solda sıra numarası, sağda ne yapılacağı.
///
/// Çip okuma iki adımlı ve ikisi de kullanıcının fiziksel olarak yapacağı
/// şeyler; sırayı görmeden kart telefonun arkasına yaslanıyor ve tarama
/// atlanıyor.
class IdentityStepRow extends StatelessWidget {
  const IdentityStepRow({
    super.key,
    required this.order,
    required this.title,
    required this.description,
  });

  /// Kullanıcıya gösterilen sıra numarası.
  final int order;

  final String title;
  final String description;

  /// Numaranın oturduğu dairenin çapı. Metin bloğunun ilk satırıyla aynı
  /// hizada dursun diye ikon dairesinden küçük.
  static const double _badgeSize = 28.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _badgeSize,
          height: _badgeSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.accentColor,
            borderRadius: AppRadius.stadiumCircular,
          ),
          child: Text(
            '$order',
            // Doygun yeşil zeminin üstünde: rengi açıkça geçilmezse
            // slotun kendi koyu rengi kalırdı.
            style: context.textTheme.labelLarge?.copyWith(
              color: AppColors.onAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.space),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.textTheme.titleSmall),
              const SizedBox(height: AppSizes.smallGap),
              Text(
                description,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
