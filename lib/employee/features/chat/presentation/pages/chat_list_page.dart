import 'package:flutter/material.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_list_controller.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  late final ChatListController _controller = ChatListController();

  /// Oturum sahibi yüklenemediyse gösterilecek mesaj; sohbetlerin kendi
  /// hataları [ChatListController] üzerinde.
  String? _sessionError;

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
      appBar: MyAppbar(title: "Sohbetlerim", showBackButton: false),
      body: _body(),
    );
  }

  Widget _body() {
    if (_controller.isLoading && _controller.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _sessionError ?? _controller.errorMessage;
    if (error != null && _controller.conversations.isEmpty) {
      return _errorState(error);
    }

    if (_controller.conversations.isEmpty) return _emptyState();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _controller.conversations.length,
        itemBuilder: (context, index) {
          final chat = _controller.conversations[index];
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
    return const EmptyState(
      icon: AppIcons.chat,
      title: 'Henüz sohbetin yok',
      description: 'Bir ilana başvurduğunda işverenle sohbet burada açılır.',
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
