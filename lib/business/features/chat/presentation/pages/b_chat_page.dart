import 'package:flutter/material.dart';
import 'package:koala/business/features/chat/services/b_chat_service.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_bubble.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_textfield.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/extensions/context_extensions.dart';

class BChatPage extends StatefulWidget {
  final Conversation chat;

  const BChatPage({super.key, required this.chat});

  @override
  State<BChatPage> createState() => _BChatPageState();
}

class _BChatPageState extends State<BChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final BChatService _chatService = BChatService();
  final ScrollController _scrollController = ScrollController();
  late List<Message> messages;

  @override
  void initState() {
    super.initState();
    messages = _chatService.getMessages(widget.chat.id);
    _chatService.markChatAsRead(widget.chat.id);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      setState(() {
        _chatService.sendMessage(
          widget.chat.id,
          _messageController.text.trim(),
        );
        messages = _chatService.getMessages(widget.chat.id);
      });
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: ChatAppBar(chat: widget.chat),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: AppPadding.primaryAll,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe = message.isMe;

                final isNextSameSender =
                    index < messages.length - 1 &&
                    messages[index + 1].isMe == isMe;

                return MessageBubble(
                  message: message,
                  isNextSameSender: isNextSameSender,
                );
              },
            ),
          ),
          MessageTextField(
            controller: _messageController,
            onSendMessage: _sendMessage,
            onAddPressed: () {},
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
