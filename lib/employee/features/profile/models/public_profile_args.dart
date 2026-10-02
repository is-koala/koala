import 'package:koala/employee/features/chat/models/chat_participant.dart';

/// `/public-profile` rotasının `extra`'sı: kimin profili açılıyor ve
/// çağıranın elinde zaten olan bilgiler.
///
/// Sunucudaki `GET /users/{id}` yanıtı ad ve fotoğrafı taşıyor ama kişinin
/// **bu bağlamdaki rolünü** (ilan sahibi mi, şirket yetkilisi mi, ekip
/// arkadaşı mı) ve şirketini taşımıyor; onu çağıran biliyor. Ad, fotoğraf ve
/// rol ekran açılır açılmaz kapağı çizebilsin diye de buradan geliyor —
/// profil yanıtı gelince kapak onunla tazeleniyor.
class PublicProfileArgs {
  const PublicProfileArgs({
    required this.userId,
    this.name,
    this.imageUrl,
    this.role = ChatParticipantRole.unknown,
    this.companyId,
    this.companyName,
  });

  /// Grup sohbetinin katılımcı satırından: kimlik, ad, fotoğraf ve sohbetteki
  /// rolü.
  factory PublicProfileArgs.fromParticipant(ChatParticipant participant) {
    return PublicProfileArgs(
      userId: participant.id,
      name: participant.fullName,
      imageUrl: participant.profilePictureUrl,
      role: participant.role,
    );
  }

  final String userId;

  /// Çağıranın bildiği ad; yoksa kapak profil yanıtını bekliyor.
  final String? name;
  final String? imageUrl;

  /// Kişinin bu bağlamdaki rolü; bilinmiyorsa [ChatParticipantRole.unknown]
  /// ve etiket çizilmiyor.
  final ChatParticipantRole role;

  /// Kişinin temsil ettiği şirket; biliniyorsa profilde şirket satırı
  /// çiziliyor ve [companyId] ile şirket sayfasına gidiyor.
  final String? companyId;
  final String? companyName;
}
