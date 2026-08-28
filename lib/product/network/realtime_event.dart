/// Sunucudan gelen anlık olayın türü. Backend `RealtimeEventType` karşılığı.
enum RealtimeEventType {
  message('MESSAGE'),
  typing('TYPING'),
  read('READ'),
  presence('PRESENCE'),

  /// Tanınmayan tür. Backend yeni bir olay eklerse istemci çökmesin diye var;
  /// dinleyiciler bunu yok sayıyor.
  unknown('');

  const RealtimeEventType(this.code);

  final String code;

  static RealtimeEventType fromCode(Object? value) {
    return RealtimeEventType.values.firstWhere(
      (type) => type.code == value,
      orElse: () => RealtimeEventType.unknown,
    );
  }
}

/// STOMP kanallarından gelen olay. Backend `RealtimeEventDto` karşılığı.
///
/// Tek bir gövde dört farklı olayı taşıyor; hangi alanın dolu olduğu [type]'a
/// bağlı. [message] ham JSON olarak duruyor çünkü `Message` modeline
/// çevirmek için oturum sahibinin kimliği gerekiyor ve o bilgi bu katmanda yok.
class RealtimeEvent {
  const RealtimeEvent({
    required this.type,
    this.conversationId,
    this.userId,
    this.message,
    this.online,
    this.at,
  });

  final RealtimeEventType type;

  /// Olayın ait olduğu sohbet. `PRESENCE` olaylarında `null`.
  final String? conversationId;

  /// Olayı tetikleyen kullanıcı: mesajı gönderen, yazan ya da okuyan.
  final String? userId;

  /// `MESSAGE` olaylarında yeni mesajın ham gövdesi (`MessageDto`).
  final Map<String, dynamic>? message;

  /// `PRESENCE` olaylarında kullanıcının çevrimiçi olup olmadığı.
  final bool? online;

  final DateTime? at;

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    final at = json['at'];

    return RealtimeEvent(
      type: RealtimeEventType.fromCode(json['type']),
      conversationId: json['conversationId'] == null
          ? null
          : '${json['conversationId']}',
      userId: json['userId'] == null ? null : '${json['userId']}',
      message: message is Map<String, dynamic> ? message : null,
      online: json['online'] as bool?,
      at: at is String ? DateTime.tryParse(at) : null,
    );
  }
}
