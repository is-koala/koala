import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/chat/services/b_chat_service.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_appbar.dart';

class BChatListPage extends StatefulWidget {
  const BChatListPage({super.key});

  @override
  State<BChatListPage> createState() => _BChatListPageState();
}

class _BChatListPageState extends State<BChatListPage> {
  final BChatService _chatService = BChatService();
  late List<Conversation> _chatList;

  /// Boş durum ikonunu taşıyan kutu.
  static const double _emptyIconBox = 80;

  /// Sohbet satırındaki avatarın ölçüleri; employee listesindekinden küçük,
  /// satır burada iki değil tek blok metin taşıyor.
  static const double _avatarSize = 54;
  static const double _avatarRadius = 16;
  static const double _avatarDotSize = 14;

  /// Okunmamış satırın zemin vurgusu; renk değil ton farkı olsun diye çok
  /// düşük opaklık.
  static const double _unreadTintAlpha = 0.04;

  @override
  void initState() {
    super.initState();
    _chatList = _chatService.getChats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      _chatList = _chatService.getChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(
        title: "Sohbetler",
        isLarge: true,
        showBackButton: false,
      ),
      body: _chatList.isEmpty ? _emptyState() : _chatListView(),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: _emptyIconBox,
              height: _emptyIconBox,
              decoration: BoxDecoration(
                color: context.tileColor,
                borderRadius: AppRadius.secondaryCircular,
              ),
              child: AppIcon(
                AppIcons.chat,
                size: AppSizes.iconLarge,
                color: context.dividerColor,
              ),
            ),
            const SizedBox(height: AppSizes.spaceLarge),
            Text(
              'Henüz sohbet yok',
              style: context.textTheme.titleMedium?.copyWith(
                color: context.textTertiary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              'Başvuranlarla iletişime geçtiğinizde\nsohbetler burada görünecek.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatListView() {
    return ListView.builder(
      padding: const EdgeInsets.only(
        top: AppSizes.spaceSmall,
        bottom: AppSizes.navBarClearance,
      ),
      itemCount: _chatList.length,
      itemBuilder: (context, index) => _chatTile(_chatList[index]),
    );
  }

  Widget _chatTile(Conversation chat) {
    final hasUnread = chat.unreadCount > 0;

    return InkWell(
      onTap: () async {
        await context.push('/business/chat-detail', extra: chat);
        // Geri döndüğünde listeyi güncelle
        if (mounted) {
          setState(() {
            _chatList = _chatService.getChats();
          });
        }
      },
      child: Container(
        padding: AppPadding.infoTile,
        decoration: BoxDecoration(
          color: hasUnread
              ? context.accentColor.withValues(alpha: _unreadTintAlpha)
              : context.backgroundColor,
          border: Border(
            bottom: BorderSide(color: context.dividerColor, width: 1),
          ),
        ),
        child: Row(
          children: [
            ChatAvatar(
              avatarUrl: chat.avatarUrl,
              fallbackText: chat.avatar,
              size: _avatarSize,
              borderRadius: _avatarRadius,
              isOnline: chat.isOnline,
              onlineDotSize: _avatarDotSize,
            ),
            const SizedBox(width: AppSizes.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.name,
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.spaceTiny),
                  Text(
                    chat.lastMessage ?? '',
                    style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                      color: hasUnread
                          ? context.textSecondary
                          : context.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.space),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chat.timeString,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: hasUnread
                        ? context.accentColor
                        : context.textTertiary,
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: AppSizes.spaceTiny),
                  _unreadBadge(chat.unreadCount),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _unreadBadge(int count) {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: context.accentColor,
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        count.toString(),
        style: context.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.onAccent,
        ),
      ),
    );
  }
}
