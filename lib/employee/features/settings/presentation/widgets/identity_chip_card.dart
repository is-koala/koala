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
///
/// Özet iki eylem taşıyor ve ikisi ayrı: **Yeniden Oku** kanıtı yenisiyle
/// değiştiriyor, **Okumayı Kaldır** kanıtı ve ondan türeyen beş alanı
/// birlikte bırakıp formu elle düzenlemeye açıyor. Kullanıcının elle
/// düzenlemeye dönmesinin başka yolu yok — kanıt dururken alanlara
/// dokunmak, ekrandaki beyanı kanıttan ayrıştırmak olurdu. (Sunucunun
/// kanıtı `IDENTITY_CHALLENGE_INVALID` ile reddetmesi de aynı geçişten
/// geçiyor; o kararı sayfa veriyor, kart yalnız sonucu çiziyor.)
class IdentityChipCard extends StatelessWidget {
  const IdentityChipCard({
    super.key,
    required this.result,
    required this.onRead,
    required this.onRemove,
  });

  /// Okuma tamamlandıysa sonuç; `null` ise henüz okunmadı.
  final IdentityChipResult? result;

  /// Kartı (yeniden) okut.
  final VoidCallback onRead;

  /// Eldeki okumayı bırak; form elle düzenlemeye dönüyor.
  final VoidCallback onRemove;

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
                      ? 'Kartın çipi doğrulandı. Ad, soyad, TC kimlik no, '
                            'seri no ve doğum tarihi karttan geldi; '
                            'değiştirmek için okumayı kaldır.'
                      : 'Kart bilgileri okundu. Ad, soyad, TC kimlik no, '
                            'seri no ve doğum tarihi karttan geldi; '
                            'değiştirmek için okumayı kaldır. Bu kart canlı '
                            'çip doğrulamasını desteklemiyor; doğrulaman '
                            'yine de tamamlanabilir.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                    height: _lineHeight,
                  ),
                ),
                Row(
                  children: [
                    _action(context, 'Yeniden Oku', onRead),
                    const SizedBox(width: AppSizes.spaceSmall),
                    _action(context, 'Okumayı Kaldır', onRemove),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, String title, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        title,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.accentColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
