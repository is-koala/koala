import 'dart:io';

import 'package:flutter/material.dart';
import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Dört kareden birinin satırı: kadraj rehberi, önizleme ve eylemler.
///
/// Kare seçilmemişken solda rehber ikonu ve "Fotoğraf Ekle"; seçildikten
/// sonra küçük önizleme, "Değiştir" ve "Kaldır". Önizlemeye dokunmak kareyi
/// tam boy açıyor: 88 piksellik kutuda kartın yazısının okunup okunmadığı
/// anlaşılmıyor, personelin reddetmesini beklemektense burada bakılsın.
class IdentityPhotoTile extends StatelessWidget {
  const IdentityPhotoTile({
    super.key,
    required this.order,
    required this.slot,
    required this.photo,
    required this.onPick,
    required this.onRemove,
    this.enabled = true,
  });

  /// Ekrandaki sıra numarası (1'den).
  final int order;

  final IdentityPhotoSlot slot;

  /// Seçilmiş kare; yoksa `null`.
  final IdentityPhoto? photo;

  /// Kare ekle / değiştir.
  final VoidCallback onPick;

  final VoidCallback onRemove;

  /// Gönderim sürerken düğmeler kapalı: yarı yolda kare değiştirmek gövdeyi
  /// bozmaz ama kullanıcıya değiştirilmiş gibi görünür.
  final bool enabled;

  /// Önizleme kutusunun kenarı. Satırın yüksekliğini bu belirliyor; üç
  /// satırlık rehber metniyle aynı boyda.
  static const double _previewSize = 88;

  /// Rehber ikonunun oturduğu kutunun zemin saydamlığı; vurgu rengi tam
  /// doygunlukta kutu olarak değil hafif bir ton olarak dursun.
  static const double _placeholderAlpha = 0.12;

  @override
  Widget build(BuildContext context) {
    final selected = photo;

    return Container(
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(
          color: selected == null ? context.dividerColor : context.accentColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _preview(context, selected),
          const SizedBox(width: AppSizes.space),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$order. ${slot.title}',
                        style: context.textTheme.titleSmall,
                      ),
                    ),
                    if (selected != null)
                      const AppIcon(
                        AppIcons.checkCircle,
                        size: AppSizes.iconMedium,
                        color: AppColors.success,
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.smallGap),
                Text(
                  slot.guide,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceTiny),
                _actions(context, selected),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context, IdentityPhoto? selected) {
    if (selected == null) {
      return Container(
        width: _previewSize,
        height: _previewSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.accentColor.withValues(alpha: _placeholderAlpha),
          borderRadius: AppRadius.innerCircular,
        ),
        child: AppIcon(
          _placeholderIcon,
          size: AppSizes.iconLarge,
          color: context.accentColor,
        ),
      );
    }

    return Semantics(
      button: true,
      label: '${slot.title} önizleme',
      child: InkWell(
        onTap: () => _openPreview(context, selected),
        borderRadius: AppRadius.innerCircular,
        child: ClipRRect(
          borderRadius: AppRadius.innerCircular,
          child: Image.file(
            File(selected.path),
            width: _previewSize,
            height: _previewSize,
            fit: BoxFit.cover,
            // Dosya silinmiş ya da çözülemiyorsa boş kutu değil bir uyarı:
            // kullanıcı kareyi yeniden seçebilsin.
            errorBuilder: (_, _, _) => Container(
              width: _previewSize,
              height: _previewSize,
              alignment: Alignment.center,
              color: context.elevatedColor,
              child: const AppIcon(AppIcons.alert, color: AppColors.warning),
            ),
          ),
        ),
      ),
    );
  }

  String get _placeholderIcon => switch (slot) {
    IdentityPhotoSlot.front => AppIcons.fileText,
    IdentityPhotoSlot.back => AppIcons.file,
    IdentityPhotoSlot.selfie => AppIcons.user,
    IdentityPhotoSlot.together => AppIcons.userCheck,
  };

  Widget _actions(BuildContext context, IdentityPhoto? selected) {
    final style = TextButton.styleFrom(
      padding: AppPadding.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: context.accentColor,
      textStyle: context.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    if (selected == null) {
      return TextButton.icon(
        onPressed: enabled ? onPick : null,
        style: style,
        icon: const AppIcon(AppIcons.camera, size: AppSizes.iconSmall),
        label: const Text('Fotoğraf Ekle'),
      );
    }

    return Row(
      children: [
        TextButton(
          onPressed: enabled ? onPick : null,
          style: style,
          child: const Text('Değiştir'),
        ),
        const SizedBox(width: AppSizes.spaceMedium),
        TextButton(
          onPressed: enabled ? onRemove : null,
          style: style.copyWith(
            foregroundColor: const WidgetStatePropertyAll(AppColors.danger),
          ),
          child: const Text('Kaldır'),
        ),
      ],
    );
  }

  /// Kareyi tam boy, yakınlaştırılabilir açar.
  Future<void> _openPreview(BuildContext context, IdentityPhoto selected) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: AppPadding.primaryAll,
        backgroundColor: context.backgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: AppPadding.tile,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      slot.title,
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: AppIcon(AppIcons.close, color: context.textPrimary),
                    tooltip: 'Kapat',
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.file(File(selected.path), fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
          ],
        ),
      ),
    );
  }
}
