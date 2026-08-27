import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/models/message.dart';

/// İşveren tarafı için ayrı ChatService — başvuran/çalışan odaklı sohbetler
class BChatService {
  static final BChatService _instance = BChatService._internal();
  factory BChatService() => _instance;
  BChatService._internal();

  // Sahte veri: jobId ve jobTitle yer tutucu, bkz. ChatService'teki not.
  final List<Conversation> _chats = [
    Conversation(
      id: 'bc_1',
      name: 'Yakup Demir',
      avatar: 'Y',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Yakup+Demir&size=256&background=72AD70&color=ffffff&bold=true&format=png',
      lastMessage: 'Merhaba, garson pozisyonu için müsaitim.',
      lastMessageAt: DateTime.now().subtract(const Duration(minutes: 15)),
      unreadCount: 2,
      isOnline: true,
      counterpartId: 'applicant_1',
      jobId: 'job_1',
      jobTitle: 'Örnek İlan 1',
    ),
    Conversation(
      id: 'bc_2',
      name: 'Ayşe Yılmaz',
      avatar: 'A',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Ayşe+Yılmaz&size=256&background=5B8DEF&color=ffffff&bold=true&format=png',
      lastMessage: '3 yıldır specialty coffee alanında çalışıyorum.',
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 1)),
      unreadCount: 1,
      isOnline: true,
      counterpartId: 'applicant_2',
      jobId: 'job_2',
      jobTitle: 'Örnek İlan 2',
    ),
    Conversation(
      id: 'bc_3',
      name: 'Mehmet Kaya',
      avatar: 'M',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Mehmet+Kaya&size=256&background=F5A623&color=ffffff&bold=true&format=png',
      lastMessage: 'Teşekkürler, bilgilendirme için.',
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 3)),
      unreadCount: 0,
      isOnline: false,
      counterpartId: 'applicant_3',
      jobId: 'job_3',
      jobTitle: 'Örnek İlan 3',
    ),
    Conversation(
      id: 'bc_4',
      name: 'Burak Şen',
      avatar: 'B',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Burak+Şen&size=256&background=9C27B0&color=ffffff&bold=true&format=png',
      lastMessage: 'Fotoğrafları yarın teslim edebilirim.',
      lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      isOnline: false,
      counterpartId: 'applicant_4',
      jobId: 'job_4',
      jobTitle: 'Örnek İlan 4',
    ),
    Conversation(
      id: 'bc_5',
      name: 'Elif Aydın',
      avatar: 'E',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Elif+Aydın&size=256&background=E91E63&color=ffffff&bold=true&format=png',
      lastMessage: 'Hafta sonu çalışabilir miyim?',
      lastMessageAt: DateTime.now().subtract(const Duration(days: 2)),
      unreadCount: 0,
      isOnline: true,
      counterpartId: 'applicant_5',
      jobId: 'job_5',
      jobTitle: 'Örnek İlan 5',
    ),
  ];

  final Map<String, List<Message>> _messages = {
    'bc_1': [
      Message(
        id: 'bm1',
        conversationId: 'bc_1',
        senderId: 'applicant_1',
        body: 'Merhaba, garson ilanınızı gördüm.',
        sentAt: DateTime.now().subtract(const Duration(minutes: 30)),
        isMe: false,
      ),
      Message(
        id: 'bm2',
        conversationId: 'bc_1',
        senderId: 'me',
        body:
            'Merhaba Yakup, başvurunu aldık! Deneyimin hakkında bilgi verir misin?',
        sentAt: DateTime.now().subtract(const Duration(minutes: 25)),
        isMe: true,
      ),
      Message(
        id: 'bm3',
        conversationId: 'bc_1',
        senderId: 'applicant_1',
        body: 'Daha önce 1 yıl kadar bir restoranda çalıştım.',
        sentAt: DateTime.now().subtract(const Duration(minutes: 20)),
        isMe: false,
      ),
      Message(
        id: 'bm4',
        conversationId: 'bc_1',
        senderId: 'applicant_1',
        body: 'Merhaba, garson pozisyonu için müsaitim.',
        sentAt: DateTime.now().subtract(const Duration(minutes: 15)),
        isMe: false,
      ),
    ],
    'bc_2': [
      Message(
        id: 'bm5',
        conversationId: 'bc_2',
        senderId: 'applicant_2',
        body: 'Merhaba, barista pozisyonuna başvurmak istiyorum.',
        sentAt: DateTime.now().subtract(const Duration(hours: 2)),
        isMe: false,
      ),
      Message(
        id: 'bm6',
        conversationId: 'bc_2',
        senderId: 'me',
        body: 'Merhaba Ayşe! Specialty coffee deneyimin var mı?',
        sentAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
        isMe: true,
      ),
      Message(
        id: 'bm7',
        conversationId: 'bc_2',
        senderId: 'applicant_2',
        body: '3 yıldır specialty coffee alanında çalışıyorum.',
        sentAt: DateTime.now().subtract(const Duration(hours: 1)),
        isMe: false,
      ),
    ],
    'bc_3': [
      Message(
        id: 'bm8',
        conversationId: 'bc_3',
        senderId: 'me',
        body:
            'Merhaba Mehmet, başvurun için teşekkürler. Seni değerlendirme sürecine aldık.',
        sentAt: DateTime.now().subtract(const Duration(hours: 4)),
        isMe: true,
      ),
      Message(
        id: 'bm9',
        conversationId: 'bc_3',
        senderId: 'applicant_3',
        body: 'Teşekkürler, bilgilendirme için.',
        sentAt: DateTime.now().subtract(const Duration(hours: 3)),
        isMe: false,
      ),
    ],
    'bc_4': [
      Message(
        id: 'bm10',
        conversationId: 'bc_4',
        senderId: 'me',
        body:
            'Burak, fotoğraf çekimi harika oldu! Fotoğrafları ne zaman teslim edebilirsin?',
        sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        isMe: true,
      ),
      Message(
        id: 'bm11',
        conversationId: 'bc_4',
        senderId: 'applicant_4',
        body: 'Fotoğrafları yarın teslim edebilirim.',
        sentAt: DateTime.now().subtract(const Duration(days: 1)),
        isMe: false,
      ),
    ],
    'bc_5': [
      Message(
        id: 'bm12',
        conversationId: 'bc_5',
        senderId: 'applicant_5',
        body: 'Merhaba, garson ilanınız hâlâ geçerli mi?',
        sentAt: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
        isMe: false,
      ),
      Message(
        id: 'bm13',
        conversationId: 'bc_5',
        senderId: 'me',
        body: 'Merhaba Elif, evet hâlâ aktif. Hangi günler müsaitsin?',
        sentAt: DateTime.now().subtract(const Duration(days: 2, minutes: 30)),
        isMe: true,
      ),
      Message(
        id: 'bm14',
        conversationId: 'bc_5',
        senderId: 'applicant_5',
        body: 'Hafta sonu çalışabilir miyim?',
        sentAt: DateTime.now().subtract(const Duration(days: 2)),
        isMe: false,
      ),
    ],
  };

  List<Conversation> getChats() => List.unmodifiable(_chats);

  Conversation? getChatById(String chatId) {
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
      conversationId: chatId,
      senderId: 'me',
      body: text,
      sentAt: DateTime.now(),
      isMe: true,
      status: MessageStatus.sent,
    );

    _messages[chatId] ??= [];
    _messages[chatId]!.add(message);

    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(
        lastMessage: text,
        lastMessageAt: DateTime.now(),
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
