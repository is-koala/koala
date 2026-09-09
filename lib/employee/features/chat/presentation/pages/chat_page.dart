import 'package:flutter/material.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/pages/chat_thread_pagemodel.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:koala/employee/features/chat/presentation/widgets/blocked_notice.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_bubble.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_textfield.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

part 'chat_pagemodel.dart';

class ChatPage extends StatefulWidget {
  final Conversation chat;

  /// Dışarıdan verilirse yaşam döngüsü çağırana ait olan sohbet durumu.
  final ChatThreadController? threadController;

  const ChatPage({super.key, required this.chat, this.threadController});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ChatPagemodel {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: thread,
      builder: (context, _) => Scaffold(
        appBar: ChatAppBar(
          chat: widget.chat,
          isTyping: thread.isCounterpartTyping,
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
    final blockedMessage = thread.blockedMessage;
    if (blockedMessage != null) return BlockedNotice(message: blockedMessage);

    return MessageTextField(
      controller: messageController,
      onSendMessage: sendMessage,
      isSending: thread.isSending,
      onChanged: (_) => thread.notifyTyping(),
      onAddPressed: () {
        // Ek menü işlemleri (dosya ekleme, galeri vb.)
      },
    );
  }

  Widget _messageList() {
    final messages = thread.messages;

    if (thread.isLoading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = sessionError ?? thread.errorMessage;
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
      controller: scrollController,
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
            OutlinedButton(
              onPressed: loadThread,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}
