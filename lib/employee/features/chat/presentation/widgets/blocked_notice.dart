import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Engelli sohbette mesaj kutusunun yerine geçen şerit.
///
/// Kutuyu kilitli göstermek yerine tamamen kaldırıyor: yazılamayan bir metin
/// alanı kullanıcıya "bir şey bozuldu" dedirtiyor, sebebini söyleyen bir
/// satır ise ne olduğunu anlatıyor.
///
/// [message] sunucunun kendi metni ("Bu kullanıcıyla mesajlaşamazsınız.") —
/// `403` genel bir "yetkin yok" metnine çevrilmiyor. Engelin kimden
/// geldiğini sunucu da söylemiyor: engel iki yönlü ve karşı taraf da
/// engellemiş olabilir.
class BlockedNotice extends StatelessWidget {
  const BlockedNotice({super.key, required this.message});

  final String message;

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
            const AppIcon(
              AppIcons.userBlock,
              size: AppSizes.iconMedium,
              color: AppColors.danger,
            ),
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
