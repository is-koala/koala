import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/block_user_action.dart';
import 'package:koala/product/widgets/report_sheet.dart';

enum _ChatAppBarAction { report, block }

/// Sohbet başlığı: avatar, ad, çevrimiçi durum ve menü; iki taraf ortak.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.chat,
    this.isTyping = false,
    this.onTitleTap,
  });

  final Conversation chat;

  final bool isTyping;

  /// Grupta katılımcıları açar; ikili sohbette `null`.
  final VoidCallback? onTitleTap;

  static const double _avatarDotSize = 12;

  static const String participantsSemanticsLabel = 'Katılımcıları göster';

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: AppIcon(AppIcons.arrowLeft, color: context.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: onTitleTap == null
          ? _title(context)
          : Semantics(
              button: true,
              label: participantsSemanticsLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTitleTap,
                child: _title(context),
              ),
            ),
      // Şikayet ve engel kişiye yönelik; grupta menü yok.
      actions: [if (!chat.isGroup) _overflowMenu(context)],
    );
  }

  Widget _title(BuildContext context) {
    return Row(
      children: [
        ChatAvatar(
          avatarUrl: chat.avatarUrl,
          fallbackText: chat.avatar,
          size: AppSizes.avatarSmall,
          borderRadius: AppRadius.avatar,
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
              // Yazıyorsa zaten çevrimiçi.
              if (isTyping)
                Text(
                  'yazıyor...',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: AppColors.success,
                    fontStyle: FontStyle.italic,
                  ),
                )
              // Grupta çevrimiçi yerine kişi sayısı.
              else if (chat.isGroup)
                Text(
                  chat.participantLabel,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.textSecondary,
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
    );
  }

  /// Şikayet ve engel nadir; iki ikon yerine tek menü.
  Widget _overflowMenu(BuildContext context) {
    return PopupMenuButton<_ChatAppBarAction>(
      icon: AppIcon(AppIcons.more, color: context.textPrimary),
      onSelected: (action) => _onAction(context, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _ChatAppBarAction.report,
          child: Text('Şikayet Et'),
        ),
        PopupMenuItem(
          value: _ChatAppBarAction.block,
          // Engelin sonucu anında ve karşılıklı; kırmızı metin ayırıyor.
          child: Text(
            'Engelle',
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppColors.danger,
            ),
          ),
        ),
      ],
    );
  }

  void _onAction(BuildContext context, _ChatAppBarAction action) {
    switch (action) {
      case _ChatAppBarAction.report:
        ReportSheet.show(
          context,
          ReportTarget.user(userId: chat.counterpartId, name: chat.name),
        );

      case _ChatAppBarAction.block:
        _block(context);
    }
  }

  /// Engeller ve çıkar: kutu kilitlenir, dönüşte liste tazelenir.
  Future<void> _block(BuildContext context) async {
    final blocked = await BlockUserAction.confirmAndBlock(
      context,
      userId: chat.counterpartId,
      name: chat.name,
    );

    if (blocked && context.mounted) context.pop();
  }
}
