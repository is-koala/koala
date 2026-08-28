import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_list_controller.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

class BChatListPage extends StatefulWidget {
  const BChatListPage({super.key});

  @override
  State<BChatListPage> createState() => _BChatListPageState();
}

class _BChatListPageState extends State<BChatListPage> {
  late final ChatListController _controller = ChatListController();

  /// Oturum sahibi yüklenemediyse gösterilecek mesaj; sohbetlerin kendi
  /// hataları [ChatListController] üzerinde.
  String? _sessionError;

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
    _controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    // Karşı tarafın kim olduğu oturum sahibine göre belirleniyor, o yüzden
    // sohbetlerden önce kullanıcının yüklenmiş olması gerekiyor.
    final userProvider = context.read<UserProvider>();
    if (userProvider.user == null) await userProvider.load();
    if (!mounted) return;

    final userId = userProvider.user?.id;
    if (userId == null) {
      setState(() {
        _sessionError =
            userProvider.errorMessage ?? 'Oturum bilgisi alınamadı.';
      });
      return;
    }

    setState(() => _sessionError = null);
    await _controller.load(currentUserId: userId);
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
      body: _body(),
    );
  }

  Widget _emptyState() {
    return const EmptyState(
      icon: AppIcons.chat,
      title: 'Henüz sohbet yok',
      description:
          'Başvuranlarla iletişime geçtiğinizde sohbetler burada görünecek.',
    );
  }

  Widget _body() {
    if (_controller.isLoading && _controller.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _sessionError ?? _controller.errorMessage;
    if (error != null && _controller.conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              OutlinedButton(
                onPressed: _load,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller.conversations.isEmpty) return _emptyState();

    return RefreshIndicator(onRefresh: _load, child: _chatListView());
  }

  Widget _chatListView() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        top: AppSizes.spaceSmall,
        bottom: AppSizes.navBarClearance,
      ),
      itemCount: _controller.conversations.length,
      itemBuilder: (context, index) =>
          _chatTile(_controller.conversations[index]),
    );
  }

  Widget _chatTile(Conversation chat) {
    final hasUnread = chat.unreadCount > 0;

    return InkWell(
      onTap: () async {
        await context.push('/business/chat-detail', extra: chat);
        // Geri döndüğünde okunmamış sayacı ve son mesaj değişmiş olur.
        if (mounted) await _load();
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
