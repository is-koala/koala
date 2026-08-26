import 'package:flutter/material.dart';
import 'package:koala/employee/features/chat/services/chat_service.dart';
import 'package:koala/employee/features/chat/models/chat.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:koala/product/widgets/my_appbar.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatService _chatService = ChatService();
  late List<Chat> chatList;

  @override
  void initState() {
    super.initState();
    chatList = _chatService.getChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: "Sohbetlerim", showBackButton: false),
      body: ListView.builder(
        itemCount: chatList.length,
        itemBuilder: (context, index) {
          final chat = chatList[index];
          return ChatListTile(chat: chat);
        },
      ),
    );
  }
}
