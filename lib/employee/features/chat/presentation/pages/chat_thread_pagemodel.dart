import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/models/message_sender.dart';
import 'package:koala/employee/features/chat/models/messaging_availability.dart';
import 'package:koala/employee/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_participants_sheet.dart';
import 'package:koala/employee/features/profile/models/public_profile_args.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/router/employee_routes.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:provider/provider.dart';

/// İki sohbet sayfasının ortak denetleyici seçimi ve yaşam döngüsü.
abstract class ChatThreadPagemodel<T extends StatefulWidget> extends State<T> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  Conversation get chat;

  ChatThreadController? get providedThreadController;

  /// Kapının metni tarafa göre değişiyor.
  bool get asEmployer;

  late ChatThreadController thread;
  late bool _ownsThread;
  int _bindingGeneration = 0;

  String? sessionError;

  /// Kutunun yerine geçecek açıklama. Öncelik: sunucunun az önceki kapısı >
  /// listedeki `closed` > engel.
  String? get composerNotice {
    final gate =
        thread.gate ?? (chat.closed ? MessagingAvailability.closed : null);
    if (gate != null) return gate.noteFor(asEmployer: asEmployer);
    return thread.blockedMessage;
  }

  /// Kilit sebebi kapı mı, engel mi. Kapı hata değil, akışın beklenen durağı;
  /// şerit bilgi ikonuyla çizilir.
  bool get isComposerGated =>
      thread.gate != null || (chat.closed && thread.blockedMessage == null);

  VoidCallback? get onTitleTap => chat.isGroup ? openParticipants : null;

  /// Kendi mesajında ve ikili sohbette `null`; kimin yazdığı hizadan belli.
  MessageSender? senderFor(Message message) =>
      chat.isGroup && !message.isMe ? thread.senderOf(message) : null;

  /// İkili sohbette boş; orada okundu `readAt` üzerinden.
  List<ChatParticipant> readersFor(Message message) =>
      chat.isGroup && message.isMe ? thread.readersOf(message) : const [];

  /// Peş peşe balonlar yakın dursun; grupta iki farklı karşı tarafı ayırmak
  /// için gönderen kimliğine bakılıyor.
  bool isNextSameSender(List<Message> messages, int index) =>
      index < messages.length - 1 &&
      messages[index + 1].senderId == messages[index].senderId;

  /// Katılımcılar sheet'i (#182); kendi satırın yalnız çalışan kabuğunda
  /// dokunulabilir.
  void openParticipants() {
    ChatParticipantsSheet.show(
      context,
      chat: chat,
      participants: thread.participants,
      currentUserId: context.read<UserProvider>().user?.id,
      onOpenProfile: openProfile,
      onOpenOwnProfile: asEmployer ? null : openOwnProfile,
    );
  }

  /// Profili kabuğun kendi sayfasında açar: işverenin aday sayfası çalışanı,
  /// çalışanın herkese açık profili işvereni geri çevirir.
  void openProfile(ChatParticipant participant) {
    if (asEmployer) {
      context.push(BusinessRoutes.userProfile, extra: participant.id);
      return;
    }
    context.push(
      EmployeeRoutes.publicProfile(participant.id),
      extra: PublicProfileArgs.fromParticipant(participant, jobId: chat.jobId),
    );
  }

  /// `go`: sekme yığının tabanı.
  void openOwnProfile() => context.go(EmployeeRoutes.ownProfile);

  @override
  void initState() {
    super.initState();

    final selection = _selectThread(
      conversationId: chat.id,
      provided: providedThreadController,
    );
    thread = selection.controller;
    _ownsThread = selection.ownsController;
    thread.addListener(_onThreadChanged);
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextConversationId = chat.id;
    final nextProvided = providedThreadController;
    _verifyConversation(nextProvided, nextConversationId);

    final keepsCurrent = nextProvided == null
        ? _ownsThread && thread.conversationId == nextConversationId
        : !_ownsThread && identical(thread, nextProvided);
    if (keepsCurrent) return;

    final selection = _selectThread(
      conversationId: nextConversationId,
      provided: nextProvided,
    );
    final previousThread = thread;
    final ownedPreviousThread = _ownsThread;

    previousThread.removeListener(_onThreadChanged);
    _bindingGeneration++;
    thread = selection.controller;
    _ownsThread = selection.ownsController;
    sessionError = null;
    thread.addListener(_onThreadChanged);

    if (ownedPreviousThread) previousThread.dispose();
    _scheduleLoad();
  }

  @override
  void dispose() {
    final selectedThread = thread;
    final ownsSelectedThread = _ownsThread;

    _bindingGeneration++;
    selectedThread.removeListener(_onThreadChanged);
    if (ownsSelectedThread) selectedThread.dispose();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _onThreadChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    });
  }

  void _scheduleLoad() {
    final generation = _bindingGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _bindingGeneration) return;
      loadThread();
    });
  }

  Future<void> loadThread() async {
    final generation = _bindingGeneration;
    final selectedThread = thread;

    // "Ben mi gönderdim" oturum sahibine göre; önce kullanıcı gerekiyor.
    final userProvider = context.read<UserProvider>();
    if (userProvider.user == null) await userProvider.load();
    if (!_isCurrent(generation, selectedThread)) return;

    final userId = userProvider.user?.id;
    if (userId == null) {
      setState(() {
        sessionError = userProvider.errorMessage ?? 'Oturum bilgisi alınamadı.';
      });
      return;
    }

    if (sessionError != null) setState(() => sessionError = null);
    await selectedThread.load(currentUserId: userId);
  }

  Future<void> sendMessage() async {
    final generation = _bindingGeneration;
    final selectedThread = thread;
    final sent = await selectedThread.send(messageController.text);
    if (!_isCurrent(generation, selectedThread)) return;
    if (!mounted) return;

    if (sent) {
      messageController.clear();
      return;
    }

    // Kapı hatası şeritteki cümleyle aynı olsun diye tarafa göre seçiliyor.
    final error =
        selectedThread.gate?.noteFor(asEmployer: asEmployer) ??
        selectedThread.errorMessage;
    if (error == null) return;

    // Metin temizlenmiyor; kullanıcı yazdığını kaybetmesin.
    AppToast.error(context, error);
  }

  bool _isCurrent(int generation, ChatThreadController selectedThread) {
    return mounted &&
        generation == _bindingGeneration &&
        identical(thread, selectedThread);
  }

  ({ChatThreadController controller, bool ownsController}) _selectThread({
    required String conversationId,
    required ChatThreadController? provided,
  }) {
    _verifyConversation(provided, conversationId);
    if (provided != null) {
      return (controller: provided, ownsController: false);
    }

    return (
      controller: ChatThreadController(
        conversationId: conversationId,
        participants: chat.participants,
      ),
      ownsController: true,
    );
  }

  void _verifyConversation(
    ChatThreadController? candidate,
    String conversationId,
  ) {
    if (candidate == null || candidate.conversationId == conversationId) {
      return;
    }

    throw ArgumentError.value(
      candidate.conversationId,
      'providedThreadController.conversationId',
      'Sayfadaki sohbet kimliğiyle aynı olmalı: $conversationId',
    );
  }
}
