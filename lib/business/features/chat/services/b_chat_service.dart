import 'package:koala/employee/features/chat/models/chat.dart';
import 'package:koala/employee/features/chat/models/message.dart';

/// İşveren tarafı için ayrı ChatService — başvuran/çalışan odaklı sohbetler
class BChatService {
  static final BChatService _instance = BChatService._internal();
  factory BChatService() => _instance;
  BChatService._internal();

  final List<Chat> _chats = [
    Chat(
      id: 'bc_1',
      name: 'Yakup Demir',
      avatar: 'Y',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Yakup+Demir&size=256&background=72AD70&color=ffffff&bold=true&format=png',
      lastMessage: 'Merhaba, garson pozisyonu için müsaitim.',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 15)),
      unreadCount: 2,
      isOnline: true,
      userId: 'applicant_1',
    ),
    Chat(
      id: 'bc_2',
      name: 'Ayşe Yılmaz',
      avatar: 'A',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Ayşe+Yılmaz&size=256&background=5B8DEF&color=ffffff&bold=true&format=png',
      lastMessage: '3 yıldır specialty coffee alanında çalışıyorum.',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
      unreadCount: 1,
      isOnline: true,
      userId: 'applicant_2',
    ),
    Chat(
      id: 'bc_3',
      name: 'Mehmet Kaya',
      avatar: 'M',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Mehmet+Kaya&size=256&background=F5A623&color=ffffff&bold=true&format=png',
      lastMessage: 'Teşekkürler, bilgilendirme için.',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 3)),
      unreadCount: 0,
      isOnline: false,
      userId: 'applicant_3',
    ),
    Chat(
      id: 'bc_4',
      name: 'Burak Şen',
      avatar: 'B',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Burak+Şen&size=256&background=9C27B0&color=ffffff&bold=true&format=png',
      lastMessage: 'Fotoğrafları yarın teslim edebilirim.',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      isOnline: false,
      userId: 'applicant_4',
    ),
    Chat(
      id: 'bc_5',
      name: 'Elif Aydın',
      avatar: 'E',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Elif+Aydın&size=256&background=E91E63&color=ffffff&bold=true&format=png',
      lastMessage: 'Hafta sonu çalışabilir miyim?',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 2)),
      unreadCount: 0,
      isOnline: true,
      userId: 'applicant_5',
    ),
  ];

  final Map<String, List<Message>> _messages = {
    'bc_1': [
      Message(
        id: 'bm1',
        chatId: 'bc_1',
        senderId: 'applicant_1',
        text: 'Merhaba, garson ilanınızı gördüm.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        isMe: false,
      ),
      Message(
        id: 'bm2',
        chatId: 'bc_1',
        senderId: 'me',
        text:
            'Merhaba Yakup, başvurunu aldık! Deneyimin hakkında bilgi verir misin?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        isMe: true,
      ),
      Message(
        id: 'bm3',
        chatId: 'bc_1',
        senderId: 'applicant_1',
        text: 'Daha önce 1 yıl kadar bir restoranda çalıştım.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
        isMe: false,
      ),
      Message(
        id: 'bm4',
        chatId: 'bc_1',
        senderId: 'applicant_1',
        text: 'Merhaba, garson pozisyonu için müsaitim.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        isMe: false,
      ),
    ],
    'bc_2': [
      Message(
        id: 'bm5',
        chatId: 'bc_2',
        senderId: 'applicant_2',
        text: 'Merhaba, barista pozisyonuna başvurmak istiyorum.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isMe: false,
      ),
      Message(
        id: 'bm6',
        chatId: 'bc_2',
        senderId: 'me',
        text: 'Merhaba Ayşe! Specialty coffee deneyimin var mı?',
        timestamp: DateTime.now().subtract(
          const Duration(hours: 1, minutes: 30),
        ),
        isMe: true,
      ),
      Message(
        id: 'bm7',
        chatId: 'bc_2',
        senderId: 'applicant_2',
        text: '3 yıldır specialty coffee alanında çalışıyorum.',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        isMe: false,
      ),
    ],
    'bc_3': [
      Message(
        id: 'bm8',
        chatId: 'bc_3',
        senderId: 'me',
        text:
            'Merhaba Mehmet, başvurun için teşekkürler. Seni değerlendirme sürecine aldık.',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        isMe: true,
      ),
      Message(
        id: 'bm9',
        chatId: 'bc_3',
        senderId: 'applicant_3',
        text: 'Teşekkürler, bilgilendirme için.',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        isMe: false,
      ),
    ],
    'bc_4': [
      Message(
        id: 'bm10',
        chatId: 'bc_4',
        senderId: 'me',
        text:
            'Burak, fotoğraf çekimi harika oldu! Fotoğrafları ne zaman teslim edebilirsin?',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        isMe: true,
      ),
      Message(
        id: 'bm11',
        chatId: 'bc_4',
        senderId: 'applicant_4',
        text: 'Fotoğrafları yarın teslim edebilirim.',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isMe: false,
      ),
    ],
    'bc_5': [
      Message(
        id: 'bm12',
        chatId: 'bc_5',
        senderId: 'applicant_5',
        text: 'Merhaba, garson ilanınız hâlâ geçerli mi?',
        timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
        isMe: false,
      ),
      Message(
        id: 'bm13',
        chatId: 'bc_5',
        senderId: 'me',
        text: 'Merhaba Elif, evet hâlâ aktif. Hangi günler müsaitsin?',
        timestamp: DateTime.now().subtract(
          const Duration(days: 2, minutes: 30),
        ),
        isMe: true,
      ),
      Message(
        id: 'bm14',
        chatId: 'bc_5',
        senderId: 'applicant_5',
        text: 'Hafta sonu çalışabilir miyim?',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isMe: false,
      ),
    ],
  };

  List<Chat> getChats() => List.unmodifiable(_chats);

  Chat? getChatById(String chatId) {
    try {
      return _chats.firstWhere((c) => c.id == chatId);
    } catch (_) {
      return null;
    }
  }

  List<Message> getMessages(String chatId) {
    return List.unmodifiable(_messages[chatId] ?? []);
  }

  void sendMessage(String chatId, String text) {
    final message = Message(
      id: 'bm_${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      senderId: 'me',
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sent,
    );

    _messages[chatId] ??= [];
    _messages[chatId]!.add(message);

    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(
        lastMessage: text,
        lastMessageTime: DateTime.now(),
      );
    }
  }

  void markChatAsRead(String chatId) {
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
    }
  }

  int get totalUnreadCount =>
      _chats.fold(0, (sum, chat) => sum + chat.unreadCount);
}
