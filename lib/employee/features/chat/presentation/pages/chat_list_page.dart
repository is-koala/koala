import 'dart:async';

import 'package:flutter/material.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/network/realtime_client.dart';
import 'package:koala/product/network/realtime_event.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatService _chatService = ChatService();
  final RealtimeClient _realtimeClient = RealtimeClient();

  StreamSubscription<RealtimeEvent>? _presence;

  List<Conversation> _chatList = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Sayfa `ShellPage`'in `PageView`'ında canlı kaldığı için yükleme bir kez
    // burada tetikleniyor; kullanıcı listeyi aşağı çekerek tazeleyebiliyor.
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

  Future<void> _load() async {
    setState(() {
      _loading = _chatList.isEmpty;
      _errorMessage = null;
    });

    try {
      // Karşı tarafın kim olduğu oturum sahibine göre belirleniyor, o yüzden
      // sohbetlerden önce kullanıcının yüklenmiş olması gerekiyor.
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

      final withPresence = await _withPresence(page.conversations);
      if (!mounted) return;

      setState(() => _chatList = withPresence);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Çevrimiçi bilgisini tek istekte alıp sohbetlere işler.
  ///
  /// Presence sohbet yanıtında gelmiyor. Bu çağrı başarısız olursa sohbetler
  /// yine gösteriliyor — yeşil noktanın yokluğu listeyi engellememeli.
  Future<List<Conversation>> _withPresence(
    List<Conversation> conversations,
  ) async {
    if (conversations.isEmpty) return conversations;

    try {
      final ids = conversations
          .map((conversation) => conversation.counterpartId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final presence = await _chatService.fetchPresence(ids);

      return conversations
          .map(
            (conversation) => conversation.copyWith(
              isOnline: presence[conversation.counterpartId]?.online ?? false,
            ),
          )
          .toList();
    } on ApiException {
      return conversations;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: "Sohbetlerim", showBackButton: false),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _chatList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _errorMessage;
    if (error != null && _chatList.isEmpty) return _errorState(error);

    if (_chatList.isEmpty) return _emptyState();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _chatList.length,
        itemBuilder: (context, index) {
          final chat = _chatList[index];
          return ChatListTile(
            chat: chat,
            // Sohbetten dönünce okunmamış sayacı ve son mesaj değişmiş olur.
            onReturn: _load,
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Henüz sohbetin yok',
              style: context.textTheme.titleMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              'Bir ilana başvurduğunda işverenle sohbet burada açılır.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            OutlinedButton(onPressed: _load, child: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }
}
