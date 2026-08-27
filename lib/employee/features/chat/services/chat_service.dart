import '../models/conversation.dart';
import '../models/message.dart';

class ChatService {
  // Singleton pattern
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  // Fake data - chat listesi (şirketlere göre)
  // Sahte veri: sohbetler ilana bağlanmadan önce yazıldığı için jobId ve
  // jobTitle yer tutucu. Gerçek veri `/conversations` uçlarından gelecek.
  final List<Conversation> _chats = [
    Conversation(
      id: '1',
      name: 'Özlem & Murat Düğün Organizasyonu',
      avatar: 'Ö',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Özlem+Murat&size=256&background=E91E63&color=ffffff&bold=true&format=png',
      lastMessage: 'Düğün için detayları konuşalım mı?',
      lastMessageAt: DateTime.now().subtract(Duration(minutes: 30)),
      unreadCount: 2,
      isOnline: true,
      counterpartId: 'user1',
      jobId: 'job_1',
      jobTitle: 'Örnek İlan 1',
    ),
    Conversation(
      id: '2',
      name: 'Kahve Durağı Cafe',
      avatar: 'K',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Kahve+Durağı&size=256&background=795548&color=ffffff&bold=true&format=png',
      lastMessage: 'Başvurunuz değerlendirildi',
      lastMessageAt: DateTime.now().subtract(Duration(hours: 1)),
      unreadCount: 0,
      isOnline: false,
      counterpartId: 'user2',
      jobId: 'job_2',
      jobTitle: 'Örnek İlan 2',
    ),
    Conversation(
      id: '3',
      name: 'Ahmet Yılmaz',
      avatar: 'A',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Ahmet+Yılmaz&size=256&background=4CAF50&color=ffffff&bold=true&format=png',
      lastMessage: 'Kedilerim için bakıcı arıyorum',
      lastMessageAt: DateTime.now().subtract(Duration(hours: 2)),
      unreadCount: 1,
      isOnline: true,
      counterpartId: 'user3',
      jobId: 'job_3',
      jobTitle: 'Örnek İlan 3',
    ),
    Conversation(
      id: '4',
      name: 'Lezzet Durağı Restaurant',
      avatar: 'L',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Lezzet+Durağı&size=256&background=FF5722&color=ffffff&bold=true&format=png',
      lastMessage: 'Teşekkürler, görüşmek üzere!',
      lastMessageAt: DateTime.now().subtract(Duration(days: 1)),
      unreadCount: 0,
      isOnline: false,
      counterpartId: 'user4',
      jobId: 'job_4',
      jobTitle: 'Örnek İlan 4',
    ),
    Conversation(
      id: '5',
      name: 'Brew & Co. Specialty Coffee',
      avatar: 'B',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Brew+Co&size=256&background=3E2723&color=ffffff&bold=true&format=png',
      lastMessage: 'Barista pozisyonu için müsait misiniz?',
      lastMessageAt: DateTime.now().subtract(Duration(days: 1, hours: 5)),
      unreadCount: 3,
      isOnline: true,
      counterpartId: 'user5',
      jobId: 'job_5',
      jobTitle: 'Örnek İlan 5',
    ),
    Conversation(
      id: '6',
      name: 'TrendShop E-ticaret',
      avatar: 'T',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Trend+Shop&size=256&background=9C27B0&color=ffffff&bold=true&format=png',
      lastMessage: 'Fotoğraf çekimi için tarih belirleyelim',
      lastMessageAt: DateTime.now().subtract(Duration(days: 2)),
      unreadCount: 0,
      isOnline: false,
      counterpartId: 'user6',
      jobId: 'job_6',
      jobTitle: 'Örnek İlan 6',
    ),
    Conversation(
      id: '7',
      name: 'Elit Organizasyon',
      avatar: 'E',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Elit+Org&size=256&background=1565C0&color=ffffff&bold=true&format=png',
      lastMessage: 'Etkinlik detayları hakkında bilgi verebilir misiniz?',
      lastMessageAt: DateTime.now().subtract(Duration(days: 3)),
      unreadCount: 1,
      isOnline: true,
      counterpartId: 'user7',
      jobId: 'job_7',
      jobTitle: 'Örnek İlan 7',
    ),
    Conversation(
      id: '8',
      name: 'Zeynep Kaya',
      avatar: 'Z',
      avatarUrl:
          'https://ui-avatars.com/api/?name=Zeynep+Kaya&size=256&background=FF8F00&color=ffffff&bold=true&format=png',
      lastMessage: 'Köpeğim için bakıcı arıyorum',
      lastMessageAt: DateTime.now().subtract(Duration(days: 4)),
      unreadCount: 0,
      isOnline: false,
      counterpartId: 'user8',
      jobId: 'job_8',
      jobTitle: 'Örnek İlan 8',
    ),
  ];

  // Fake data - mesajlar (chat id'ye göre)
  final Map<String, List<Message>> _messages = {
    '1': [
      Message(
        id: 'm1',
        conversationId: '1',
        senderId: 'user1',
        body: 'Merhaba! Düğün organizasyonu için ilanınızı gördüm.',
        sentAt: DateTime.now().subtract(Duration(minutes: 35)),
        isMe: false,
      ),
      Message(
        id: 'm2',
        conversationId: '1',
        senderId: 'me',
        body: 'Merhaba, evet düğün için organizasyon hizmeti veriyoruz.',
        sentAt: DateTime.now().subtract(Duration(minutes: 34)),
        isMe: true,
      ),
      Message(
        id: 'm3',
        conversationId: '1',
        senderId: 'user1',
        body: 'Harika! Fiyat ve tarih hakkında bilgi alabilir miyim?',
        sentAt: DateTime.now().subtract(Duration(minutes: 33)),
        isMe: false,
      ),
      Message(
        id: 'm4',
        conversationId: '1',
        senderId: 'me',
        body: 'Tabii, düğün tarihiniz ne zaman?',
        sentAt: DateTime.now().subtract(Duration(minutes: 32)),
        isMe: true,
      ),
      Message(
        id: 'm5',
        conversationId: '1',
        senderId: 'user1',
        body: 'Düğün için detayları konuşalım mı?',
        sentAt: DateTime.now().subtract(Duration(minutes: 30)),
        isMe: false,
      ),
    ],
    '2': [
      Message(
        id: 'm6',
        conversationId: '2',
        senderId: 'user2',
        body: 'Merhaba, barista pozisyonu için başvurmak istiyorum.',
        sentAt: DateTime.now().subtract(Duration(hours: 2)),
        isMe: false,
      ),
      Message(
        id: 'm7',
        conversationId: '2',
        senderId: 'me',
        body: 'Merhaba! Başvurunuzu aldık, teşekkürler.',
        sentAt: DateTime.now().subtract(Duration(hours: 1, minutes: 30)),
        isMe: true,
      ),
      Message(
        id: 'm8',
        conversationId: '2',
        senderId: 'user2',
        body: 'Başvurunuz değerlendirildi',
        sentAt: DateTime.now().subtract(Duration(hours: 1)),
        isMe: false,
      ),
    ],
    '3': [
      Message(
        id: 'm9',
        conversationId: '3',
        senderId: 'user3',
        body: 'Merhaba, kedilerime bakacak birini arıyorum.',
        sentAt: DateTime.now().subtract(Duration(hours: 3)),
        isMe: false,
      ),
      Message(
        id: 'm10',
        conversationId: '3',
        senderId: 'me',
        body:
            'Merhaba! Kaç kediniz var ve ne kadar süreliğine bakıcı arıyorsunuz?',
        sentAt: DateTime.now().subtract(Duration(hours: 2, minutes: 30)),
        isMe: true,
      ),
      Message(
        id: 'm11',
        conversationId: '3',
        senderId: 'user3',
        body: 'Kedilerim için bakıcı arıyorum',
        sentAt: DateTime.now().subtract(Duration(hours: 2)),
        isMe: false,
      ),
    ],
    '4': [
      Message(
        id: 'm12',
        conversationId: '4',
        senderId: 'me',
        body: 'Görüşme için teşekkür ederim.',
        sentAt: DateTime.now().subtract(Duration(days: 1, hours: 1)),
        isMe: true,
      ),
      Message(
        id: 'm13',
        conversationId: '4',
        senderId: 'user4',
        body: 'Teşekkürler, görüşmek üzere!',
        sentAt: DateTime.now().subtract(Duration(days: 1)),
        isMe: false,
      ),
    ],
    '5': [
      Message(
        id: 'm14',
        conversationId: '5',
        senderId: 'user5',
        body: 'Barista pozisyonu için müsait misiniz?',
        sentAt: DateTime.now().subtract(Duration(days: 1, hours: 5)),
        isMe: false,
      ),
    ],
    '6': [
      Message(
        id: 'm15',
        conversationId: '6',
        senderId: 'user6',
        body: 'Ürün fotoğrafı çekimi için fiyat teklifi alabilir miyim?',
        sentAt: DateTime.now().subtract(Duration(days: 2, hours: 1)),
        isMe: false,
      ),
      Message(
        id: 'm16',
        conversationId: '6',
        senderId: 'me',
        body: 'Tabii, kaç ürün için çekim yapılacak?',
        sentAt: DateTime.now().subtract(Duration(days: 2, minutes: 30)),
        isMe: true,
      ),
      Message(
        id: 'm17',
        conversationId: '6',
        senderId: 'user6',
        body: 'Fotoğraf çekimi için tarih belirleyelim',
        sentAt: DateTime.now().subtract(Duration(days: 2)),
        isMe: false,
      ),
    ],
    '7': [
      Message(
        id: 'm18',
        conversationId: '7',
        senderId: 'user7',
        body: 'Etkinlik detayları hakkında bilgi verebilir misiniz?',
        sentAt: DateTime.now().subtract(Duration(days: 3)),
        isMe: false,
      ),
    ],
    '8': [
      Message(
        id: 'm19',
        conversationId: '8',
        senderId: 'user8',
        body: 'Merhaba, Golden Retriever\'ım için bakıcı arıyorum.',
        sentAt: DateTime.now().subtract(Duration(days: 4, hours: 1)),
        isMe: false,
      ),
      Message(
        id: 'm20',
        conversationId: '8',
        senderId: 'me',
        body: 'Merhaba! Ne kadar süreliğine bakıcı arıyorsunuz?',
        sentAt: DateTime.now().subtract(Duration(days: 4, minutes: 30)),
        isMe: true,
      ),
      Message(
        id: 'm21',
        conversationId: '8',
        senderId: 'user8',
        body: 'Köpeğim için bakıcı arıyorum',
        sentAt: DateTime.now().subtract(Duration(days: 4)),
        isMe: false,
      ),
    ],
  };

  // Conversation listesini getir
  List<Conversation> getChats() {
    return List.unmodifiable(_chats);
  }

  // Belirli bir chat'i getir
  Conversation? getChatById(String chatId) {
    try {
      return _chats.firstWhere((chat) => chat.id == chatId);
    } catch (e) {
      return null;
    }
  }

  /// Şirket kimliğinden sohbete giden eşleme.
  ///
  /// Eşleme modelde değil burada duruyor: sunucuda sohbet **ilana** bağlı
  /// (`POST /conversations/jobs/{jobId}`), şirkete bağlı bir sohbet kavramı
  /// yok. Şirket detayındaki "mesaj gönder" akışı bu yüzden gerçek uca
  /// olduğu gibi bağlanamıyor.
  /// TODO(backend): Ya şirket detayından mesaj gönderme kaldırılıp yerini
  /// ilan üzerinden sohbete bırakmalı, ya da sunucu şirket bazlı sohbeti de
  /// desteklemeli.
  final Map<String, String> _conversationIdsByCompany = {};

  // CompanyId'ye göre chat getir
  Conversation? getChatByCompanyId(String companyId) {
    final conversationId = _conversationIdsByCompany[companyId];
    if (conversationId == null) return null;

    return getChatById(conversationId);
  }

  // CompanyId'ye göre chat getir veya yeni oluştur
  Conversation getOrCreateChatByCompany({
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
    final newChat = Conversation(
      id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      name: companyName,
      avatar: Conversation.initialsOf(companyName),
      avatarUrl:
          avatarUrl ??
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(companyName)}&size=256&background=607D8B&color=ffffff&bold=true&format=png',
      lastMessage: null,
      lastMessageAt: DateTime.now(),
      unreadCount: 0,
      isOnline: false,
      counterpartId: 'company_$companyId',
      jobId: '',
      jobTitle: '',
    );

    _chats.insert(0, newChat);
    _conversationIdsByCompany[companyId] = newChat.id;
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
      conversationId: chatId,
      senderId: 'me',
      body: text,
      sentAt: DateTime.now(),
      isMe: true,
      status: MessageStatus.sent,
    );

    if (_messages[chatId] == null) {
      _messages[chatId] = [];
    }
    _messages[chatId]!.add(message);

    // Conversation'in son mesajını ve zamanını güncelle
    final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);
    if (chatIndex != -1) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(
        lastMessage: text,
        lastMessageAt: DateTime.now(),
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
  void createChat(Conversation chat) {
    _chats.insert(0, chat);
  }

  // Conversation sil
  void deleteChat(String chatId) {
    _chats.removeWhere((chat) => chat.id == chatId);
    _messages.remove(chatId);
  }
}
