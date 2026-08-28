import 'package:flutter/material.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_bubble.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_textfield.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
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
  final ChatService _chatService = ChatService();

  List<Message> messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _errorMessage;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = messages.isEmpty;
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

      final page = await _chatService.fetchMessages(
        conversationId: widget.chat.id,
        currentUserId: userId,
      );
      if (!mounted) return;

      setState(() {
        _currentUserId = userId;
        messages = page.messages;
      });

      _scrollToBottom();

      // Okundu işaretlemek listedeki sayacı sıfırlıyor; başarısız olursa
      // mesajları göstermeyi engellememeli.
      try {
        await _chatService.markRead(widget.chat.id);
      } on ApiException {
        // Yut: bir sonraki açılışta tekrar denenecek.
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    final userId = _currentUserId;
    if (body.isEmpty || userId == null || _sending) return;

    setState(() => _sending = true);

    try {
      final message = await _chatService.sendMessage(
        conversationId: widget.chat.id,
        currentUserId: userId,
        body: body,
      );
      if (!mounted) return;

      setState(() => messages = [...messages, message]);
      _messageController.clear();
      _scrollToBottom();
    } on ApiException catch (error) {
      if (!mounted) return;
      // Metin alanı temizlenmiyor: kullanıcı yazdığını kaybetmesin.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Yeni mesaj eklendiğinde en alta kaydırır; liste eskiden yeniye çiziliyor.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBar(chat: widget.chat),
      body: Column(
        children: [
          Expanded(child: _messageList()),
          MessageTextField(
            controller: _messageController,
            onSendMessage: _sendMessage,
            isSending: _sending,
            onAddPressed: () {
              // Ek menü işlemleri (dosya ekleme, galeri vb.)
            },
          ),
        ],
      ),
    );
  }

  Widget _messageList() {
    if (_loading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _errorMessage;
    if (error != null && messages.isEmpty) {
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
}
