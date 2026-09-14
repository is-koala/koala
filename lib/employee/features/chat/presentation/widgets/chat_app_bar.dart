import 'package:flutter/material.dart';
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

/// Sohbet başlığının taşma menüsündeki eylemler.
///
/// Yeni bir eylem eklenirken buraya bir değer, menüye bir `PopupMenuItem` ve
/// [ChatAppBar._onAction]'a bir dal giriyor.
enum _ChatAppBarAction { report, block }

/// Sohbet detayının başlığı: avatar, ad, çevrimiçi durumu ve taşma menüsü.
///
/// Employee ve business tarafı aynı sohbet ekranını kullanıyor; başlık da
/// ortak — buradaki tek değişiklik iki uygulamayı birden kapsıyor.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.chat,
    this.isTyping = false,
    this.onTitleTap,
  });

  final Conversation chat;

  /// Karşı taraf şu an yazıyor mu. Canlı bağlantıdan geliyor ve kısa süre
  /// sonra kendiliğinden sönüyor.
  final bool isTyping;

  /// Başlığa (avatar + ad) dokununca çalışır; grupta katılımcılar sayfasını
  /// açıyor. `null` ise başlık dokunulmuyor — ikili sohbette öyle.
  final VoidCallback? onTitleTap;

  /// Başlıktaki çevrimiçi noktası; listedekinden küçük.
  static const double _avatarDotSize = 12;

  /// Erişilebilirlik etiketi: grupta başlık katılımcıları açan bir düğme.
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
      // Şikayet ve engel bir kişiye yönelik; grupta hedef alınacak tek bir
      // karşı taraf olmadığı için menü çizilmiyor.
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
              // Grupta tek bir karşı taraf yok; çevrimiçi yerine ekibin
              // kaç kişi olduğu yazılıyor.
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

  /// Sohbetin taşma menüsü: şikayet ve engelleme.
  ///
  /// İkisi de karşı tarafa yönelik ve ikisi de nadir kullanılıyor; başlıkta
  /// iki ayrı ikon yerine tek menü duruyor.
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
          // Şikayetten farkı sonucun anında ve karşılıklı olması; kırmızı
          // metin ikisini menüde ayırıyor.
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
        // Şikayet edilen karşı taraf; sohbetin kendisi değil.
        ReportSheet.show(
          context,
          ReportTarget.user(userId: chat.counterpartId, name: chat.name),
        );

      case _ChatAppBarAction.block:
        _block(context);
    }
  }

  /// Karşı tarafı engeller ve sohbetten çıkar.
  ///
  /// Ekranda kalmanın anlamı yok: mesaj kutusu kilitleniyor ve iki taraf da
  /// yazamıyor. Geri çıkmak ayrıca sohbet listesini de tazeliyor —
  /// `ChatListTile.onReturn` dönüşte listeyi yeniden çekiyor.
  Future<void> _block(BuildContext context) async {
    final blocked = await BlockUserAction.confirmAndBlock(
      context,
      userId: chat.counterpartId,
      name: chat.name,
    );

    if (blocked && context.mounted) context.pop();
  }
}
