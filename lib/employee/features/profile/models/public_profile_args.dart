import 'package:koala/employee/features/chat/models/chat_participant.dart';

/// Herkese açık profil rotasının isteğe bağlı `extra`'sı: çağıranın elinde
/// zaten olan bilgiler (is-koala/koala#182).
///
/// Kimlik buradan **değil yol parametresinden** geliyor
/// (`EmployeeRoutes.publicProfile(userId)`); bu sınıf yalnızca kapağı
/// önceden doldurmak ve profil yanıtının taşımadığı bağlamı iletmek için.
/// Sunucudaki `GET /users/{id}` yanıtı kişinin **bu bağlamdaki rolünü** (ilan
/// sahibi mi, şirket yetkilisi mi, ekip arkadaşı mı) taşımıyor; onu çağıran
/// biliyor. Ad, fotoğraf ve rol ekran açılır açılmaz kapağı çizebilsin diye de
/// buradan geliyor — profil yanıtı gelince kapak onunla tazeleniyor.
class PublicProfileArgs {
  const PublicProfileArgs({
    required this.userId,
    this.name,
    this.imageUrl,
    this.role = ChatParticipantRole.unknown,
    this.jobId,
  });

  /// Grup sohbetinin katılımcı satırından: kimlik, ad, fotoğraf ve sohbetteki
  /// rolü. [jobId] sohbetin bağlı olduğu ilan; kişi şirket tarafındaysa şirket
  /// satırı o ilandan çözülüyor.
  factory PublicProfileArgs.fromParticipant(
    ChatParticipant participant, {
    String? jobId,
  }) {
    return PublicProfileArgs(
      userId: participant.id,
      name: participant.fullName,
      imageUrl: participant.profilePictureUrl,
      role: participant.role,
      jobId: jobId,
    );
  }

  final String userId;

  /// Çağıranın bildiği ad; yoksa kapak profil yanıtını bekliyor.
  final String? name;
  final String? imageUrl;

  /// Kişinin bu bağlamdaki rolü; bilinmiyorsa [ChatParticipantRole.unknown]
  /// ve etiket çizilmiyor.
  final ChatParticipantRole role;

  /// Kişinin işveren ya da şirket yetkilisi olarak bağlı olduğu ilan.
  /// Verilirse ve ilan bir **şirket ilanıysa** profilde şirket satırı
  /// çiziliyor (`company{id,name}` ilan detayından); bireysel ilanda ya da
  /// ilan okunamazsa satır yok.
  final String? jobId;

  /// Rol şirket satırı çizmeyi gerektiriyor mu: işveren ve şirket yetkilisi
  /// ilan bağlamında bir şirketi temsil edebilir, çalışan etmez.
  bool get mayRepresentCompany =>
      role == ChatParticipantRole.employer ||
      role == ChatParticipantRole.companyContact;
}
