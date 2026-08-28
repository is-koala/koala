import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/network/realtime_event.dart';
import 'package:provider/provider.dart';
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
  final ChatService _chatService = ChatService();
  final RealtimeClient _realtimeClient = RealtimeClient();

  StreamSubscription<RealtimeEvent>? _presence;

  List<Conversation> _chatList = [];
  bool _loading = true;
  String? _errorMessage;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
    _listenToPresence();
  }

  @override
  void dispose() {
    unawaited(_presence?.cancel());
    super.dispose();
  }

  /// Çevrimiçi değişimlerini canlı dinler.
  ///
  /// TODO(backend): Yeni mesajlar için kullanıcıya özel bir kanal yok.
  /// `RealtimePublisher` yalnızca `/topic/conversations/{id}`'ye yayın
  /// yapıyor; liste bütün sohbetlere tek tek abone olmadan yeni mesajı
  /// öğrenemiyor. `/user/queue/...` üzerinden tek bir akış gerekiyor.
  void _listenToPresence() {
    unawaited(_realtimeClient.connect());

    _presence = _realtimeClient.presenceEvents().listen((event) {
      final userId = event.userId;
      final online = event.online;
      if (userId == null || online == null || !mounted) return;

      final index = _chatList.indexWhere(
        (conversation) => conversation.counterpartId == userId,
      );
      if (index == -1) return;

      setState(() {
        _chatList = [..._chatList]
          ..[index] = _chatList[index].copyWith(isOnline: online);
      });
    });
  }

  /// Sohbetler çalışan tarafıyla aynı uçtan geliyor: `GET /conversations`
  /// oturum sahibinin bütün sohbetlerini döndürüyor, rolüne bakmıyor.
  Future<void> _load() async {
    setState(() {
      _loading = _chatList.isEmpty;
      _errorMessage = null;
    });

    try {
      final userProvider = context.read<UserProvider>();
      if (userProvider.user == null) await userProvider.load();
      if (!mounted) return;

      final userId = userProvider.user?.id;
      if (userId == null) {
        setState(() {
          _errorMessage =
              userProvider.errorMessage ?? 'Oturum bilgisi alınamadı.';
        });
        return;
      }

      final page = await _chatService.fetchConversations(currentUserId: userId);
      if (!mounted) return;

      setState(() => _chatList = page.conversations);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  Widget _body() {
    if (_loading && _chatList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _errorMessage;
    if (error != null && _chatList.isEmpty) {
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

    if (_chatList.isEmpty) return _emptyState();

    return RefreshIndicator(onRefresh: _load, child: _chatListView());
  }

  Widget _chatListView() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
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
