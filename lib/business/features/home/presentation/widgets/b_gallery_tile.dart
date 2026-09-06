import 'package:flutter/material.dart';
import 'package:koala/employee/features/company_detail/models/company_image.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Galeri yönetimindeki tek bir görsel satırı.
///
/// Sayfadan ayrı bir dosyada çünkü satır hem önizlemeyi hem rozeti hem de iki
/// eylemi taşıyor; `build` içinde kalsaydı sıralama listesinin kendisi
/// okunmaz hâle gelirdi.
class BGalleryTile extends StatelessWidget {
  const BGalleryTile({
    super.key,
    required this.image,
    required this.position,
    required this.canManage,
    this.onSetCover,
    this.onRemove,
  });

  final CompanyImage image;

  /// Görselin listedeki sırası (1'den başlayan). Başlığı olmayan görsele ad
  /// olarak yazılıyor.
  final int position;

  /// Ekleme, sıralama ve kaldırma yalnız şirketin `ADMIN` yetkilisinde.
  final bool canManage;

  final VoidCallback? onSetCover;
  final VoidCallback? onRemove;

  /// Önizlemenin kenar uzunluğu. Liste satırındaki kare görselle aynı ölçü.
  static const double _previewSize = AppSizes.thumbnail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.card,
      margin: const EdgeInsets.only(bottom: AppSizes.space),
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        children: [
          _preview(context),
          const SizedBox(width: AppSizes.spaceMedium),
          Expanded(child: _details(context)),
          if (canManage) ...[
            const SizedBox(width: AppSizes.spaceSmall),
            // Sürükleme tutamacı değil, sürüklenebileceğini söyleyen ipucu:
            // `ReorderableListView` satırın tamamını uzun basmaya bağlıyor.
            AppIcon(
              AppIcons.sort,
              size: AppSizes.iconMedium,
              color: context.textTertiary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.smallCircular,
      child: SizedBox.square(
        dimension: _previewSize,
        child: ColoredBox(
          color: context.elevatedColor,
          child: Image.network(
            image.url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => AppIcon(
              AppIcons.gallery,
              size: AppSizes.iconLarge,
              color: context.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _details(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          image.caption?.isNotEmpty == true
              ? image.caption!
              : '$position. görsel',
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (image.isCover) ...[
          const SizedBox(height: AppSizes.spaceTiny),
          _coverBadge(context),
        ],
        if (canManage) _actions(context),
      ],
    );
  }

  /// Kapak rozeti. Kapağı sunucu belirliyor; bu yalnız onu gösteriyor.
  Widget _coverBadge(BuildContext context) {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: context.accentColor,
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        'Kapak',
        style: context.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.onAccentColor,
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      children: [
        if (!image.isCover)
          TextButton(
            onPressed: onSetCover,
            style: TextButton.styleFrom(
              foregroundColor: context.accentColor,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Kapak Yap'),
          ),
        if (!image.isCover) const SizedBox(width: AppSizes.spaceMedium),
        TextButton(
          onPressed: onRemove,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.danger,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Kaldır'),
        ),
      ],
    );
  }
}
