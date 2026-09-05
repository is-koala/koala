import 'package:flutter/material.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:koala/employee/features/chat/presentation/widgets/blocked_notice.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_bubble.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_textfield.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:provider/provider.dart';

class ChatPage extends StatefulWidget {
  final Conversation chat;

  const ChatPage({super.key, required this.chat});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final ChatThreadController _thread = ChatThreadController(
    conversationId: widget.chat.id,
  );

  /// Oturum sahibi yüklenemediyse gösterilecek mesaj. Sohbetin kendi hataları
  /// [ChatThreadController] üzerinde.
  String? _sessionError;

  @override
  void initState() {
    super.initState();
    _thread.addListener(_onThreadChanged);
    _load();
  }

  @override
  void dispose() {
    _thread.removeListener(_onThreadChanged);
    _thread.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Mesaj eklendiğinde en alta kaydır; liste eskiden yeniye çiziliyor.
  void _onThreadChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _load() async {
    // Bir mesajı "ben mi gönderdim" ayrımı oturum sahibine göre yapılıyor,
    // o yüzden mesajlardan önce kullanıcı gerekiyor.
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
    await _thread.load(currentUserId: userId);
  }

  Future<void> _sendMessage() async {
    final sent = await _thread.send(_messageController.text);
    if (!mounted) return;

    if (sent) {
      _messageController.clear();
      return;
    }

    final error = _thread.errorMessage;
    if (error == null) return;

    // Metin alanı temizlenmiyor: kullanıcı yazdığını kaybetmesin.
    AppToast.error(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _thread,
      builder: (context, _) => Scaffold(
        appBar: ChatAppBar(
          chat: widget.chat,
          isTyping: _thread.isCounterpartTyping,
        ),
        body: Column(
          children: [
            Expanded(child: _messageList()),
            // Engelli sohbette mesaj kutusu yerine sebebini söyleyen şerit
            // duruyor; engel iki yönlü, yazmayı denemenin anlamı yok.
            _composer(),
          ],
        ),
      ),
    );
  }

  /// Mesaj kutusu — sohbet engelliyse yerine [BlockedNotice].
  Widget _composer() {
    final blockedMessage = _thread.blockedMessage;
    if (blockedMessage != null) return BlockedNotice(message: blockedMessage);

    return MessageTextField(
      controller: _messageController,
      onSendMessage: _sendMessage,
      isSending: _thread.isSending,
      onChanged: (_) => _thread.notifyTyping(),
      onAddPressed: () {
        // Ek menü işlemleri (dosya ekleme, galeri vb.)
      },
    );
  }

  Widget _messageList() {
    final messages = _thread.messages;

    if (_thread.isLoading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _sessionError ?? _thread.errorMessage;
    if (error != null && messages.isEmpty) return _errorState(error);

    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Text(
            'Henüz mesaj yok. İlk mesajı sen yaz.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textTertiary,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: AppPadding.primaryAll,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];

        final isNextSameSender =
            index < messages.length - 1 &&
            messages[index + 1].isMe == message.isMe;

        return MessageBubble(
          message: message,
          isNextSameSender: isNextSameSender,
        );
      },
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
