import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Yazılamayan sohbette kutunun yerine geçen şerit; kilitli alan "bir şey
/// bozuldu" dedirtir. Engelde metin sunucunun; kimden geldiği söylenmez. Kapıda
/// aynı şerit bilgi tonunda ([icon], [iconColor]).
class BlockedNotice extends StatelessWidget {
  const BlockedNotice({
    super.key,
    required this.message,
    this.icon = AppIcons.userBlock,
    this.iconColor = AppColors.danger,
  });

  final String message;

  final AppIconData icon;

  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: AppPadding.infoTile,
        decoration: BoxDecoration(color: context.backgroundColor),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(icon, size: AppSizes.iconMedium, color: iconColor),
            const SizedBox(width: AppSizes.spaceSmall),
            Expanded(
              child: Text(
                message,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
