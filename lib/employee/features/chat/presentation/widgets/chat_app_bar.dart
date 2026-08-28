import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Sohbet detayının başlığı: avatar, ad ve çevrimiçi durumu.
///
/// Employee ve business tarafı aynı sohbet ekranını kullanıyor; başlık da
/// ortak.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key, required this.chat, this.isTyping = false});

  final Conversation chat;

  /// Karşı taraf şu an yazıyor mu. Canlı bağlantıdan geliyor ve kısa süre
  /// sonra kendiliğinden sönüyor.
  final bool isTyping;

  /// Başlıktaki avatarın ölçüleri; sohbet listesindekinden küçük.
  static const double _avatarSize = 40;
  static const double _avatarRadius = 14;
  static const double _avatarDotSize = 12;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: AppIcon(AppIcons.arrowLeft, color: context.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          ChatAvatar(
            avatarUrl: chat.avatarUrl,
            fallbackText: chat.avatar,
            size: _avatarSize,
            borderRadius: _avatarRadius,
            isOnline: chat.isOnline,
            onlineDotSize: _avatarDotSize,
          ),
          const SizedBox(width: AppSizes.space),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat.name,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // "Yazıyor" çevrimiçi bilgisinin yerine geçiyor: ikisi de
                // aynı satırda ve yazıyorsa zaten çevrimiçi.
                if (isTyping)
                  Text(
                    'yazıyor...',
                    style: context.textTheme.labelMedium?.copyWith(
                      color: AppColors.success,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else if (chat.isOnline)
                  Text(
                    'Çevrimiçi',
                    style: context.textTheme.labelMedium?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
