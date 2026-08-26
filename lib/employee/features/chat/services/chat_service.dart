import '../models/chat.dart';
import '../models/message.dart';

class ChatService {
  // Singleton pattern
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  // Fake data - chat listesi (şirketlere göre)
  final List<Chat> _chats = [
    Chat(
      id: '1',
      name: 'Özlem & Murat Düğün Organizasyonu',
      avatar: 'Ö',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Özlem+Murat&size=256&background=E91E63&color=ffffff&bold=true&format=png',
      lastMessage: 'Düğün için detayları konuşalım mı?',
      lastMessageTime: DateTime.now().subtract(Duration(minutes: 30)),
      unreadCount: 2,
      isOnline: true,
      userId: 'user1',
      companyId: 'comp_1',
    ),
    Chat(
      id: '2',
      name: 'Kahve Durağı Cafe',
      avatar: 'K',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Kahve+Durağı&size=256&background=795548&color=ffffff&bold=true&format=png',
      lastMessage: 'Başvurunuz değerlendirildi',
      lastMessageTime: DateTime.now().subtract(Duration(hours: 1)),
      unreadCount: 0,
      isOnline: false,
      userId: 'user2',
      companyId: 'comp_2',
    ),
    Chat(
      id: '3',
      name: 'Ahmet Yılmaz',
      avatar: 'A',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Ahmet+Yılmaz&size=256&background=4CAF50&color=ffffff&bold=true&format=png',
      lastMessage: 'Kedilerim için bakıcı arıyorum',
      lastMessageTime: DateTime.now().subtract(Duration(hours: 2)),
      unreadCount: 1,
      isOnline: true,
      userId: 'user3',
      companyId: 'comp_3',
    ),
    Chat(
      id: '4',
      name: 'Lezzet Durağı Restaurant',
      avatar: 'L',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Lezzet+Durağı&size=256&background=FF5722&color=ffffff&bold=true&format=png',
      lastMessage: 'Teşekkürler, görüşmek üzere!',
      lastMessageTime: DateTime.now().subtract(Duration(days: 1)),
      unreadCount: 0,
      isOnline: false,
      userId: 'user4',
      companyId: 'comp_4',
    ),
    Chat(
      id: '5',
      name: 'Brew & Co. Specialty Coffee',
      avatar: 'B',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Brew+Co&size=256&background=3E2723&color=ffffff&bold=true&format=png',
      lastMessage: 'Barista pozisyonu için müsait misiniz?',
      lastMessageTime: DateTime.now().subtract(Duration(days: 1, hours: 5)),
      unreadCount: 3,
      isOnline: true,
      userId: 'user5',
      companyId: 'comp_5',
    ),
    Chat(
      id: '6',
      name: 'TrendShop E-ticaret',
      avatar: 'T',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Trend+Shop&size=256&background=9C27B0&color=ffffff&bold=true&format=png',
      lastMessage: 'Fotoğraf çekimi için tarih belirleyelim',
      lastMessageTime: DateTime.now().subtract(Duration(days: 2)),
      unreadCount: 0,
      isOnline: false,
      userId: 'user6',
      companyId: 'comp_6',
    ),
    Chat(
      id: '7',
      name: 'Elit Organizasyon',
      avatar: 'E',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Elit+Org&size=256&background=1565C0&color=ffffff&bold=true&format=png',
      lastMessage: 'Etkinlik detayları hakkında bilgi verebilir misiniz?',
      lastMessageTime: DateTime.now().subtract(Duration(days: 3)),
      unreadCount: 1,
      isOnline: true,
      userId: 'user7',
      companyId: 'comp_7',
    ),
    Chat(
      id: '8',
      name: 'Zeynep Kaya',
      avatar: 'Z',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Zeynep+Kaya&size=256&background=FF8F00&color=ffffff&bold=true&format=png',
      lastMessage: 'Köpeğim için bakıcı arıyorum',
      lastMessageTime: DateTime.now().subtract(Duration(days: 4)),
      unreadCount: 0,
      isOnline: false,
      userId: 'user8',
      companyId: 'comp_8',
    ),
  ];

  // Fake data - mesajlar (chat id'ye göre)
  final Map<String, List<Message>> _messages = {
    '1': [
      Message(
        id: 'm1',
        chatId: '1',
        senderId: 'user1',
        text: 'Merhaba! Düğün organizasyonu için ilanınızı gördüm.',
        timestamp: DateTime.now().subtract(Duration(minutes: 35)),
        isMe: false,
      ),
      Message(
        id: 'm2',
        chatId: '1',
        senderId: 'me',
        text: 'Merhaba, evet düğün için organizasyon hizmeti veriyoruz.',
        timestamp: DateTime.now().subtract(Duration(minutes: 34)),
        isMe: true,
      ),
      Message(
        id: 'm3',
        chatId: '1',
        senderId: 'user1',
        text: 'Harika! Fiyat ve tarih hakkında bilgi alabilir miyim?',
        timestamp: DateTime.now().subtract(Duration(minutes: 33)),
        isMe: false,
      ),
      Message(
        id: 'm4',
        chatId: '1',
        senderId: 'me',
        text: 'Tabii, düğün tarihiniz ne zaman?',
        timestamp: DateTime.now().subtract(Duration(minutes: 32)),
        isMe: true,
      ),
      Message(
        id: 'm5',
        chatId: '1',
        senderId: 'user1',
        text: 'Düğün için detayları konuşalım mı?',
        timestamp: DateTime.now().subtract(Duration(minutes: 30)),
        isMe: false,
      ),
    ],
    '2': [
      Message(
        id: 'm6',
        chatId: '2',
        senderId: 'user2',
        text: 'Merhaba, barista pozisyonu için başvurmak istiyorum.',
        timestamp: DateTime.now().subtract(Duration(hours: 2)),
        isMe: false,
      ),
      Message(
        id: 'm7',
        chatId: '2',
        senderId: 'me',
        text: 'Merhaba! Başvurunuzu aldık, teşekkürler.',
        timestamp: DateTime.now().subtract(Duration(hours: 1, minutes: 30)),
        isMe: true,
      ),
      Message(
        id: 'm8',
        chatId: '2',
        senderId: 'user2',
        text: 'Başvurunuz değerlendirildi',
        timestamp: DateTime.now().subtract(Duration(hours: 1)),
        isMe: false,
      ),
    ],
    '3': [
      Message(
        id: 'm9',
        chatId: '3',
        senderId: 'user3',
        text: 'Merhaba, kedilerime bakacak birini arıyorum.',
        timestamp: DateTime.now().subtract(Duration(hours: 3)),
        isMe: false,
      ),
      Message(
        id: 'm10',
        chatId: '3',
        senderId: 'me',
        text:
            'Merhaba! Kaç kediniz var ve ne kadar süreliğine bakıcı arıyorsunuz?',
        timestamp: DateTime.now().subtract(Duration(hours: 2, minutes: 30)),
        isMe: true,
      ),
      Message(
        id: 'm11',
        chatId: '3',
        senderId: 'user3',
        text: 'Kedilerim için bakıcı arıyorum',
        timestamp: DateTime.now().subtract(Duration(hours: 2)),
        isMe: false,
      ),
    ],
    '4': [
      Message(
        id: 'm12',
        chatId: '4',
        senderId: 'me',
        text: 'Görüşme için teşekkür ederim.',
        timestamp: DateTime.now().subtract(Duration(days: 1, hours: 1)),
        isMe: true,
      ),
      Message(
        id: 'm13',
        chatId: '4',
        senderId: 'user4',
        text: 'Teşekkürler, görüşmek üzere!',
        timestamp: DateTime.now().subtract(Duration(days: 1)),
        isMe: false,
      ),
    ],
    '5': [
      Message(
        id: 'm14',
        chatId: '5',
        senderId: 'user5',
        text: 'Barista pozisyonu için müsait misiniz?',
        timestamp: DateTime.now().subtract(Duration(days: 1, hours: 5)),
        isMe: false,
      ),
    ],
    '6': [
      Message(
        id: 'm15',
        chatId: '6',
        senderId: 'user6',
        text: 'Ürün fotoğrafı çekimi için fiyat teklifi alabilir miyim?',
        timestamp: DateTime.now().subtract(Duration(days: 2, hours: 1)),
        isMe: false,
      ),
      Message(
        id: 'm16',
        chatId: '6',
        senderId: 'me',
        text: 'Tabii, kaç ürün için çekim yapılacak?',
        timestamp: DateTime.now().subtract(Duration(days: 2, minutes: 30)),
        isMe: true,
      ),
      Message(
        id: 'm17',
        chatId: '6',
        senderId: 'user6',
        text: 'Fotoğraf çekimi için tarih belirleyelim',
        timestamp: DateTime.now().subtract(Duration(days: 2)),
        isMe: false,
      ),
    ],
    '7': [
      Message(
        id: 'm18',
        chatId: '7',
        senderId: 'user7',
        text: 'Etkinlik detayları hakkında bilgi verebilir misiniz?',
        timestamp: DateTime.now().subtract(Duration(days: 3)),
        isMe: false,
      ),
    ],
    '8': [
      Message(
        id: 'm19',
        chatId: '8',
        senderId: 'user8',
        text: 'Merhaba, Golden Retriever\'ım için bakıcı arıyorum.',
        timestamp: DateTime.now().subtract(Duration(days: 4, hours: 1)),
        isMe: false,
      ),
      Message(
        id: 'm20',
        chatId: '8',
        senderId: 'me',
        text: 'Merhaba! Ne kadar süreliğine bakıcı arıyorsunuz?',
        timestamp: DateTime.now().subtract(Duration(days: 4, minutes: 30)),
        isMe: true,
      ),
      Message(
        id: 'm21',
        chatId: '8',
        senderId: 'user8',
        text: 'Köpeğim için bakıcı arıyorum',
        timestamp: DateTime.now().subtract(Duration(days: 4)),
        isMe: false,
      ),
    ],
  };

  // Chat listesini getir
  List<Chat> getChats() {
    return List.unmodifiable(_chats);
  }

  // Belirli bir chat'i getir
  Chat? getChatById(String chatId) {
    try {
      return _chats.firstWhere((chat) => chat.id == chatId);
    } catch (e) {
      return null;
    }
  }

  // CompanyId'ye göre chat getir
  Chat? getChatByCompanyId(String companyId) {
    try {
      return _chats.firstWhere((chat) => chat.companyId == companyId);
    } catch (e) {
      return null;
    }
  }

  // CompanyId'ye göre chat getir veya yeni oluştur
  Chat getOrCreateChatByCompany({
    required String companyId,
    required String companyName,
    String? avatarUrl,
  }) {
    // Önce mevcut chat var mı kontrol et
    final existingChat = getChatByCompanyId(companyId);
    if (existingChat != null) {
      return existingChat;
    }

    // Yoksa yeni chat oluştur
    final newChat = Chat(
      id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      name: companyName,
      avatar: companyName.isNotEmpty ? companyName[0].toUpperCase() : 'C',
      avatarUrl:
          avatarUrl ??
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(companyName)}&size=256&background=607D8B&color=ffffff&bold=true&format=png',
      lastMessage: null,
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      isOnline: false,
      userId: 'company_$companyId',
      companyId: companyId,
    );

    _chats.insert(0, newChat);
    return newChat;
  }

  // Belirli bir chat'e ait mesajları getir
  List<Message> getMessages(String chatId) {
    return List.unmodifiable(_messages[chatId] ?? []);
  }

  // Yeni mesaj gönder
  void sendMessage(String chatId, String text) {
    final message = Message(
      id: 'm${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      senderId: 'me',
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sent,
    );

    if (_messages[chatId] == null) {
      _messages[chatId] = [];
    }
    _messages[chatId]!.add(message);

    // Chat'in son mesajını ve zamanını güncelle
    final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);
    if (chatIndex != -1) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(
        lastMessage: text,
        lastMessageTime: DateTime.now(),
      );
    }
  }

  // Mesaj silme (gelecekte backend'e bağlanacak)
  void deleteMessage(String chatId, String messageId) {
    _messages[chatId]?.removeWhere((msg) => msg.id == messageId);
  }

  // Okunmamış mesaj sayısını sıfırla
  void markChatAsRead(String chatId) {
    final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);
    if (chatIndex != -1) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
    }
  }

  // Yeni chat oluştur (gelecekte backend'e bağlanacak)
  void createChat(Chat chat) {
    _chats.insert(0, chat);
  }

  // Chat sil
  void deleteChat(String chatId) {
    _chats.removeWhere((chat) => chat.id == chatId);
    _messages.remove(chatId);
  }
}
