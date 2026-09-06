import 'package:flutter/material.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Kimlik ekranındaki çip okuma kartı.
///
/// İki hâli var ve ikisi de aynı yeri kaplıyor: okumadan **önce** ne
/// kazanılacağını anlatan bir davet, okumadan **sonra** neyin
/// kanıtlandığını söyleyen bir özet.
///
/// Davet metni "zorunlu" demiyor, çünkü değil: çip okunmadan da doğrulama
/// tamamlanıyor.
class IdentityChipCard extends StatelessWidget {
  const IdentityChipCard({
    super.key,
    required this.result,
    required this.onRead,
  });

  /// Okuma tamamlandıysa sonuç; `null` ise henüz okunmadı.
  final IdentityChipResult? result;

  final VoidCallback onRead;

  /// Bilgilendirme metinlerinin satır aralığı; ekranın geri kalanıyla aynı.
  static const double _lineHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    final read = result;
    return read == null ? _invitation(context) : _summary(context, read);
  }

  Widget _invitation(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(color: context.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(AppIcons.antenna, color: context.accentColor),
              const SizedBox(width: AppSizes.spaceSmall),
              Expanded(
                child: Text(
                  'Kimlik kartını telefona okut',
                  style: context.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            'Kartın çipini okutursan bilgiler karttan geliyor ve doğrulama '
            'daha güvenilir oluyor. İstemezsen bilgileri aşağıya elle de '
            'girebilirsin.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
              height: _lineHeight,
            ),
          ),
          const SizedBox(height: AppSizes.space),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onRead,
              child: Text(
                'Kartı Okut',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, IdentityChipResult read) {
    // DG15 taşımayan kartta canlı çip doğrulaması yapılamıyor ve akış yine
    // tamamlanıyor. İkisini aynı metinle anlatmak, olmayan bir şeyi
    // yapılmış göstermek olurdu.
    final proved = read.evidence.provesChipPresence;

    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(AppIcons.checkCircle, color: AppColors.success),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kimlik kartı okundu',
                  style: context.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSizes.smallGap),
                Text(
                  proved
                      ? 'Kartın çipi doğrulandı. Seri numarası ve doğum '
                            'tarihi karttan geldi.'
                      : 'Kart bilgileri okundu. Bu kart canlı çip '
                            'doğrulamasını desteklemiyor; doğrulaman yine de '
                            'tamamlanabilir.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                    height: _lineHeight,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onRead,
                    child: Text(
                      'Yeniden Oku',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
