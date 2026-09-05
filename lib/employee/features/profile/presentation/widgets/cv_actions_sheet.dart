import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Özgeçmiş dosyası için sunulan yükleme, değiştirme ve kaldırma eylemleri.
class CvActionsSheet extends StatelessWidget {
  const CvActionsSheet({
    super.key,
    required this.hasCv,
    required this.onUpload,
    required this.onDelete,
  });

  final bool hasCv;
  final VoidCallback onUpload;
  final VoidCallback onDelete;

  static Future<void> show(
    BuildContext context, {
    required bool hasCv,
    required VoidCallback onUpload,
    required VoidCallback onDelete,
  }) {
    return AppBottomSheet.show<void>(
      context,
      builder: (sheetContext) => CvActionsSheet(
        hasCv: hasCv,
        onUpload: () {
          Navigator.pop(sheetContext);
          onUpload();
        },
        onDelete: () {
          Navigator.pop(sheetContext);
          onDelete();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Özgeçmiş',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CvActionRow(
            icon: AppIcons.file,
            title: hasCv ? 'Özgeçmişi Değiştir' : 'Özgeçmiş Yükle',
            onTap: onUpload,
          ),
          if (hasCv) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            _CvActionRow(
              icon: AppIcons.delete,
              title: 'Özgeçmişi Kaldır',
              onTap: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

class _CvActionRow extends StatelessWidget {
  const _CvActionRow({
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
