import 'package:koala/employee/features/chat/models/conversation.dart';

/// Katılımcının sohbetteki rolü. Backend `ConversationParticipantDto.role`
/// karşılığı; sunucu sütun tutmuyor, okuma anında hesaplıyor (ilan sahibi →
/// işveren, atama satırı olan → çalışan, kalanı şirket yetkilisi).
enum ChatParticipantRole {
  employer('EMPLOYER', 'İşveren'),
  companyContact('COMPANY_CONTACT', 'Şirket yetkilisi'),
  worker('WORKER', 'Çalışan'),

  /// Alan gelmedi ya da tanınmadı: eski sunucu rolü taşımıyor. Etiket boş
  /// kalıyor; yanlış bir rol yazmaktansa hiç yazmamak yeğ.
  unknown('', '');

  const ChatParticipantRole(this.code, this.label);

  final String code;

  /// Katılımcı satırındaki etiket; [unknown] için boş.
  final String label;

  static ChatParticipantRole fromCode(Object? value) {
    for (final role in values) {
      if (role != unknown && role.code == value) return role;
    }
    return unknown;
  }
}

/// Bir sohbetin katılımcısı. Backend `ConversationParticipantDto` karşılığı
/// (is-koala/koala-backend#281).
///
/// Ayrılanlar `left=true` ile listede kalıyor ki eski mesajların adı hâlâ
/// çözülebilsin; hesabını silen katılımcı sunucudan anonim adıyla geliyor.
/// `lastReadAt` kişi başına okundu damgası: "kimler gördü" bu alandan,
/// `readAt`'ten değil hesaplanıyor — grupta `readAt` ilk okuyan herkes adına
/// dolduruyor. Eski sunucu bu alanları hiç göndermiyor; o zaman rol
/// [ChatParticipantRole.unknown], tarihler `null` ve görüldü bilgisi gizli.
class ChatParticipant {
  const ChatParticipant({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePictureUrl,
    this.role = ChatParticipantRole.unknown,
    this.joinedAt,
    this.lastReadAt,
    this.left = false,
  });

  /// Silinmiş hesap için gösterilen ad; sunucunun anonimleştirmesiyle aynı
  /// söz, adı hiç çözülemeyen gönderen için istemcinin yedeği.
  static const String anonymousName = 'Anonim Kullanıcı';

  /// Kullanıcı kimliği; `MessageDto.senderId` ile aynı.
  final String id;

  final String firstName;
  final String lastName;
  final String? profilePictureUrl;
  final ChatParticipantRole role;

  /// Sohbete katılma anı; eski sunucuda `null`.
  final DateTime? joinedAt;

  /// Kişinin sohbeti en son okuduğu an; hiç okumadıysa ya da eski sunucuda
  /// `null`.
  final DateTime? lastReadAt;

  /// Sohbetten ayrıldı mı (atama iptali, şirketten çıkarılma, hesap silme).
  final bool left;

  /// Görünen ad; iki alan da boşsa [anonymousName].
  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? anonymousName : name;
  }

  /// Görsel yokken avatarın baş harfleri.
  String get initials => Conversation.initialsOf(fullName);

  /// [sentAt] anında gönderilen mesajı bu kişi gördü mü.
  bool hasReadSince(DateTime sentAt) {
    final lastReadAt = this.lastReadAt;
    return lastReadAt != null && !lastReadAt.isBefore(sentAt);
  }

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    final joinedAt = json['joinedAt'];
    final lastReadAt = json['lastReadAt'];

    return ChatParticipant(
      id: '${json['id']}',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      profilePictureUrl: json['profilePictureUrl'] as String?,
      role: ChatParticipantRole.fromCode(json['role']),
      joinedAt: joinedAt is String ? DateTime.tryParse(joinedAt) : null,
      lastReadAt: lastReadAt is String ? DateTime.tryParse(lastReadAt) : null,
      left: json['left'] == true,
    );
  }

  ChatParticipant copyWith({DateTime? lastReadAt}) {
    return ChatParticipant(
      id: id,
      firstName: firstName,
      lastName: lastName,
      profilePictureUrl: profilePictureUrl,
      role: role,
      joinedAt: joinedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      left: left,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'profilePictureUrl': profilePictureUrl,
      'role': role.code,
      'joinedAt': joinedAt?.toIso8601String(),
      'lastReadAt': lastReadAt?.toIso8601String(),
      'left': left,
    };
  }
}
