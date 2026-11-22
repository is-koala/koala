import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Çip okuma kartı: okumadan önce davet, sonra özet. "Zorunlu" demez; çipsiz de
/// doğrulama tamamlanır. **Yeniden Oku** kanıtı değiştirir, **Okumayı Kaldır**
/// kanıtı ve beş alanı bırakıp formu elle düzenlemeye açar.
class IdentityChipCard extends StatelessWidget {
  const IdentityChipCard({
    super.key,
    required this.result,
    required this.onRead,
    required this.onRemove,
  });

  final IdentityChipResult? result;

  final VoidCallback onRead;

  final VoidCallback onRemove;

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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(AppIcons.personalCard, color: context.textPrimary),
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRead,
              style: context.accentOutlinedButtonStyle,
              child: const Text('Kartı Okut'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, IdentityChipResult read) {
    // DG15'siz kartta canlı doğrulama yok; aynı metin olmayan şeyi yapılmış
    // gösterirdi.
    final proved = read.evidence.provesChipPresence;

    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
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
