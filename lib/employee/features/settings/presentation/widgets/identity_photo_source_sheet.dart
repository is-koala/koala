import 'package:flutter/material.dart';
import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Kare için kaynak seçimi: kamera ya da galeri.
///
/// Kadraj rehberi burada bir kez daha yazıyor: kullanıcı kamerayı açmadan
/// hemen önce ne çekeceğini görsün, çekip döndükten sonra değil.
class IdentityPhotoSourceSheet extends StatelessWidget {
  const IdentityPhotoSourceSheet({super.key, required this.slot});

  final IdentityPhotoSlot slot;

  /// Sheet'i açar; seçilen kaynakla, vazgeçildiyse `null` ile kapanır.
  static Future<IdentityPhotoSource?> show(
    BuildContext context, {
    required IdentityPhotoSlot slot,
  }) {
    return AppBottomSheet.show<IdentityPhotoSource>(
      context,
      builder: (_) => IdentityPhotoSourceSheet(slot: slot),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: slot.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slot.guide,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          _SourceRow(
            icon: AppIcons.camera,
            title: 'Kamerayla Çek',
            onTap: () => Navigator.pop(context, IdentityPhotoSource.camera),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          _SourceRow(
            icon: AppIcons.gallery,
            title: 'Galeriden Seç',
            onTap: () => Navigator.pop(context, IdentityPhotoSource.gallery),
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final String icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: InkWell(
        borderRadius: AppRadius.innerCircular,
        onTap: onTap,
        child: Padding(
          padding: AppPadding.tileTall,
          child: Row(
            children: [
              AppIcon(icon, color: context.textPrimary),
              const SizedBox(width: AppSizes.spaceMedium),
              Expanded(child: Text(title, style: context.textTheme.titleSmall)),
            ],
          ),
        ),
      ),
    );
  }
}
