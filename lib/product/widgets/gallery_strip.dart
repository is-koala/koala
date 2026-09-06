import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Sıralı bir galerinin yatay şeridi.
///
/// Şirket ve ilan galerileri aynı backend modelini taşır. Şerit listeyi
/// yeniden sıralamaz; sunucunun döndürdüğü sırayı olduğu gibi gösterir.
class GalleryStrip extends StatelessWidget {
  const GalleryStrip({super.key, required this.images});

  final List<GalleryImage> images;

  static const double _stripHeight = 140;
  static const double _cardWidth = 180;
  static const double _captionScrimAlpha = 0.45;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _stripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.space),
        itemBuilder: (context, index) => _card(context, index),
      ),
    );
  }

  Widget _card(BuildContext context, int index) {
    final image = images[index];

    return GestureDetector(
      onTap: () => GalleryViewer.open(context, images, index),
      child: ClipRRect(
        borderRadius: AppRadius.innerCircular,
        child: SizedBox(
          width: _cardWidth,
          child: ColoredBox(
            color: context.tileColor,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  image.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(context),
                ),
                if (image.caption?.isNotEmpty == true)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _caption(context, image.caption!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Center(
      child: AppIcon(
        AppIcons.gallery,
        size: AppSizes.iconLarge,
        color: context.textTertiary,
      ),
    );
  }

  Widget _caption(BuildContext context, String caption) {
    return Container(
      padding: AppPadding.badge,
      color: AppColors.scrim.withValues(alpha: _captionScrimAlpha),
      child: Text(
        caption,
        style: context.textTheme.labelSmall?.copyWith(
          color: AppColors.onAccent,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Galeriyi yakınlaştırma desteğiyle tam ekran gösteren sayfa.
class GalleryViewer extends StatefulWidget {
  const GalleryViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  final List<GalleryImage> images;
  final int initialIndex;

  static Future<void> open(
    BuildContext context,
    List<GalleryImage> images,
    int initialIndex,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            GalleryViewer(images: images, initialIndex: initialIndex),
      ),
    );
  }

  @override
  State<GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<GalleryViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scrim,
      appBar: AppBar(
        backgroundColor: AppColors.scrim,
        elevation: 0,
        leading: IconButton(
          icon: const AppIcon(AppIcons.arrowLeft, color: AppColors.onAccent),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        itemBuilder: (context, index) => _page(context, widget.images[index]),
      ),
    );
  }

  Widget _page(BuildContext context, GalleryImage image) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: InteractiveViewer(
            child: Image.network(
              image.url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const AppIcon(
                AppIcons.gallery,
                size: AppSizes.iconHuge,
                color: AppColors.onAccent,
              ),
            ),
          ),
        ),
        if (image.caption?.isNotEmpty == true)
          Padding(
            padding: AppPadding.primaryAll,
            child: Text(
              image.caption!,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppColors.onAccent,
              ),
            ),
          ),
      ],
    );
  }
}
