import 'package:koala/employee/features/chat/models/messaging_gate_error_codes.dart';

/// Mesajlaşmanın neden açık/kapalı olduğu: ücret emanete alınana kadar kapalı,
/// iş bitiminden 7 gün sonra kapanıyor.
enum MessagingAvailabilityReason {
  /// Sunucu `403 MESSAGING_PAYMENT_REQUIRED` döndürüyor.
  paymentRequired('PAYMENT_REQUIRED'),

  /// İptal, ret, iade ya da 7 gün geçti; `409 MESSAGING_WINDOW_CLOSED`.
  closed('CLOSED'),

  available('AVAILABLE');

  const MessagingAvailabilityReason(this.code);

  final String code;

  static MessagingAvailabilityReason? fromCode(Object? value) {
    for (final reason in values) {
      if (reason.code == value) return reason;
    }
    return null;
  }
}

/// Mesajlaşma kapısı. **Alanların yokluğu kapalı demek**: eski sunucu da ödeme
/// öncesi reddediyor. Varsayılan [paymentRequired].
class MessagingAvailability {
  const MessagingAvailability._(this.reason);

  static const available = MessagingAvailability._(
    MessagingAvailabilityReason.available,
  );

  /// Alan gelmediğinde de bu.
  static const paymentRequired = MessagingAvailability._(
    MessagingAvailabilityReason.paymentRequired,
  );

  static const closed = MessagingAvailability._(
    MessagingAvailabilityReason.closed,
  );

  static const workerPaymentNote =
      'Mesajlaşma, işveren ödemeyi tamamladığında açılır.';

  static const employerPaymentNote =
      'Ödemeyi tamamlayınca ekip sohbeti açılır.';

  static const closedNote = 'Bu sohbet kapandı';

  final MessagingAvailabilityReason reason;

  bool get isAvailable => reason == MessagingAvailabilityReason.available;

  bool get needsPayment =>
      reason == MessagingAvailabilityReason.paymentRequired;

  bool get isClosed => reason == MessagingAvailabilityReason.closed;

  String? noteFor({required bool asEmployer}) {
    return switch (reason) {
      MessagingAvailabilityReason.available => null,
      MessagingAvailabilityReason.paymentRequired =>
        asEmployer ? employerPaymentNote : workerPaymentNote,
      MessagingAvailabilityReason.closed => closedNote,
    };
  }

  /// Sebep yoksa, tanınmıyorsa ya da kapıyla çelişiyorsa [paymentRequired].
  factory MessagingAvailability.fromJson(Map<String, dynamic> json) {
    if (json['messagingAvailable'] == true) return available;

    return switch (MessagingAvailabilityReason.fromCode(
      json['messagingAvailableReason'],
    )) {
      MessagingAvailabilityReason.closed => closed,
      _ => paymentRequired,
    };
  }

  /// Kapı hatasını çevirir. Kategori yetmiyor: aynı `403` engel için de
  /// geliyor.
  static MessagingAvailability? fromErrorCode(String? errorCode) {
    return switch (errorCode) {
      MessagingGateErrorCodes.paymentRequired => paymentRequired,
      MessagingGateErrorCodes.windowClosed => closed,
      _ => null,
    };
  }
}
