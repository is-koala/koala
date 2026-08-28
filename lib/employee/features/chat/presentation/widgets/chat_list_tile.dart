import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

class ChatListTile extends StatelessWidget {
  final Conversation chat;

  /// Sohbetten dönüldüğünde çağrılıyor: okunmamış sayacı ve son mesaj
  /// değişmiş olabilir, liste tazelenmeli.
  final Future<void> Function()? onReturn;

  const ChatListTile({super.key, required this.chat, this.onReturn});

  /// Satır yüksekliği avatardan büyük: avatarın altında ve üstünde eşit pay
  /// kalsın ve bütün satırlar aynı boyda dursun.
  static const double _tileHeight = 74;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await context.push('/chat-detail', extra: chat);
        await onReturn?.call();
      },
      child: Container(
        height: _tileHeight,
        padding: AppPadding.tile,
        margin: const EdgeInsets.only(bottom: AppSizes.spaceTiny),
        child: Row(
          children: [
            ChatAvatar(
              avatarUrl: chat.avatarUrl,
              fallbackText: chat.avatar,
              isOnline: chat.isOnline,
            ),
            const SizedBox(width: AppSizes.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    chat.name,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.spaceTiny),
                  Text(
                    chat.lastMessage ?? '',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.spaceMedium),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(chat.timeString, style: context.textTheme.labelMedium),
                if (chat.unreadCount > 0) _unreadBadge(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _unreadBadge(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSizes.spaceTiny),
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        chat.unreadCount.toString(),
        // Rozet zemini temadan bağımsız kırmızı; üstündeki sayı da öyle.
        style: context.textTheme.labelSmall?.copyWith(
          color: AppColors.onAccent,
        ),
      ),
    );
  }
}
