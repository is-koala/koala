import 'package:material_ui/material_ui.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Galeri yönetimindeki tek görsel satırı.
class BGalleryTile extends StatelessWidget {
  const BGalleryTile({
    super.key,
    required this.image,
    required this.position,
    required this.canManage,
    this.onSetCover,
    this.onRemove,
  });

  final GalleryImage image;

  /// 1'den başlar; başlıksız görsele ad olarak yazılır.
  final int position;

  final bool canManage;

  final VoidCallback? onSetCover;
  final VoidCallback? onRemove;

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
            // Tutamaç değil ipucu: `ReorderableListView` satırın tamamını uzun
            // basmaya bağlıyor.
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

  /// Kapağı sunucu belirliyor; bu yalnız gösteriyor.
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
