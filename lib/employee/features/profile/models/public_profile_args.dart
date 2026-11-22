import 'package:koala/employee/features/chat/models/chat_participant.dart';

/// Herkese açık profil rotasının isteğe bağlı `extra`'sı (#182). Kimlik yol
/// parametresinde; bu yalnız kapağı önceden doldurmak ve profil yanıtının
/// taşımadığı rolü iletmek için.
class PublicProfileArgs {
  const PublicProfileArgs({
    required this.userId,
    this.name,
    this.imageUrl,
    this.role = ChatParticipantRole.unknown,
    this.jobId,
  });

  /// Grup sohbeti katılımcısından. İlan **yalnız hâlâ sohbette olana**
  /// veriliyor: ayrılan yetkiliye verilse profilinde ayrıldığı şirket yazardı.
  factory PublicProfileArgs.fromParticipant(
    ChatParticipant participant, {
    String? jobId,
  }) {
    final hasJob = !participant.left && jobId != null && jobId.isNotEmpty;
    return PublicProfileArgs(
      userId: participant.id,
      name: participant.fullName,
      imageUrl: participant.profilePictureUrl,
      role: participant.role,
      jobId: hasJob ? jobId : null,
    );
  }

  final String userId;

  final String? name;
  final String? imageUrl;

  /// Bilinmiyorsa etiket çizilmez.
  final ChatParticipantRole role;

  /// Şirket ilanıysa profilde şirket satırı çizilir.
  final String? jobId;

  /// İşveren ve şirket yetkilisi bir şirketi temsil edebilir, çalışan etmez.
  bool get mayRepresentCompany =>
      role == ChatParticipantRole.employer ||
      role == ChatParticipantRole.companyContact;

  /// Okunmayacaksa `null`; boş kimlik `GET /jobs/` atardı.
  String? get companyLookupJobId {
    final id = jobId;
    if (id == null || id.isEmpty || !mayRepresentCompany) return null;
    return id;
  }
}
