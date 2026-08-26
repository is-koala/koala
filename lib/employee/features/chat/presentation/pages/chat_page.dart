import 'package:flutter/material.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/chat/models/chat.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_bubble.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_textfield.dart';
import 'package:koala/product/constants/app_padding.dart';

class ChatPage extends StatefulWidget {
  final Chat chat;

  const ChatPage({super.key, required this.chat});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  late List<Message> messages;

  @override
  void initState() {
    super.initState();
    messages = _chatService.getMessages(widget.chat.id);
    _chatService.markChatAsRead(widget.chat.id);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBar(chat: widget.chat),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
            onAddPressed: () {
              // Ek menü işlemleri (dosya ekleme, galeri vb.)
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
