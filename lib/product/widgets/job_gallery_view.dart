import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/product/widgets/gallery_strip.dart';

/// İlan galerisinin salt okunur yüzeyi.
///
/// İki uygulama da aynı yükleme/boş/hata ayrımını kullanır. Boş galeri hiç
/// çizilmez; galeri bir ilanın zorunlu alanı değildir.
class JobGalleryView extends StatelessWidget {
  const JobGalleryView({
    super.key,
    required this.images,
    required this.isLoading,
    this.errorMessage,
    this.onRetry,
  });

  final List<GalleryImage> images;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && errorMessage == null && images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Galeri', style: context.textTheme.titleSmall),
        const SizedBox(height: AppSizes.spaceSmall),
        if (isLoading)
          const Center(
            child: SizedBox.square(
              dimension: AppSizes.icon,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (errorMessage != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  errorMessage!,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Tekrar dene'),
                ),
            ],
          )
        else
          GalleryStrip(images: images),
      ],
    );
  }
}
