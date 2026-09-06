import 'package:flutter/material.dart';
import 'package:koala/employee/features/company_detail/models/company_image.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Şirket galerisinin yatay kaydırmalı şeridi.
///
/// Sunucu galeriyi sıralı döndürüyor ve kapağı kendisi belirliyor; şerit
/// listeyi olduğu gibi çiziyor. Görsele dokununca tam ekran görüntüleyici
/// açılıyor.
class CompanyGalleryStrip extends StatelessWidget {
  const CompanyGalleryStrip({super.key, required this.images});

  final List<CompanyImage> images;

  /// Şeridin yüksekliği. Kartın en-boy oranı yaklaşık 4:3 duruyor ve iki
  /// kart yan yana ekrana sığıyor.
  static const double _stripHeight = 140;

  /// Tek bir kartın genişliği.
  static const double _cardWidth = 180;

  /// Başlık şeridindeki karartmanın opaklığı: fotoğraf seçilsin ama yazı
  /// okunabilsin.
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
      onTap: () => CompanyGalleryViewer.open(context, images, index),
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

  /// Başlık şeridi. Zemin karartması temadan bağımsız: metin fotoğrafın
  /// üstünde duruyor, iki temada da aynı fotoğraf.
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

/// Galeriyi tam ekran gösteren sayfa.
///
/// Zemin ve üstündeki her şey temadan bağımsız: fotoğraf iki temada da aynı,
/// o yüzden arka plan her zaman koyu ve ikonlar beyaz.
class CompanyGalleryViewer extends StatefulWidget {
  const CompanyGalleryViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  final List<CompanyImage> images;
  final int initialIndex;

  static Future<void> open(
    BuildContext context,
    List<CompanyImage> images,
    int initialIndex,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            CompanyGalleryViewer(images: images, initialIndex: initialIndex),
      ),
    );
  }

  @override
  State<CompanyGalleryViewer> createState() => _CompanyGalleryViewerState();
}

class _CompanyGalleryViewerState extends State<CompanyGalleryViewer> {
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

  Widget _page(BuildContext context, CompanyImage image) {
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
