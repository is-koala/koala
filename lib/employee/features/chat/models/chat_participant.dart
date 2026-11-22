import 'package:koala/employee/features/chat/models/conversation.dart';

/// Katılımcının sohbetteki rolü; sunucu okuma anında hesaplıyor.
enum ChatParticipantRole {
  employer('EMPLOYER', 'İşveren'),
  companyContact('COMPANY_CONTACT', 'Şirket yetkilisi'),
  worker('WORKER', 'Çalışan'),

  /// Eski sunucu rolü taşımıyor; yanlış rol yazmaktansa boş.
  unknown('', '');

  const ChatParticipantRole(this.code, this.label);

  final String code;

  final String label;

  static ChatParticipantRole fromCode(Object? value) {
    for (final role in values) {
      if (role != unknown && role.code == value) return role;
    }
    return unknown;
  }
}

/// Sohbet katılımcısı. Ayrılanlar `left=true` ile kalıyor ki eski mesajların
/// adı çözülsün. "Kimler gördü" `lastReadAt`'ten: grupta `readAt` ilk okuyan
/// herkes adına doluyor. Eski sunucuda rol bilinmez, görüldü gizli.
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

  /// Sunucunun anonimleştirmesiyle aynı söz.
  static const String anonymousName = 'Anonim Kullanıcı';

  static const String leftLabel = 'Ayrıldı';

  final String id;

  final String firstName;
  final String lastName;
  final String? profilePictureUrl;
  final ChatParticipantRole role;

  final DateTime? joinedAt;

  final DateTime? lastReadAt;

  /// Atama iptali, şirketten çıkarılma, hesap silme.
  final bool left;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? anonymousName : name;
  }

  String get initials => Conversation.initialsOf(fullName);

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
