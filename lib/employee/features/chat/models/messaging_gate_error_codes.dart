/// Mesajlaşma kapısının hata kodları. Ayrı dosyada: `backend_error_codes_test`
/// buradaki dizgeleri kataloğa karşı sabitliyor, sebep kodları girmemeli.
abstract final class MessagingGateErrorCodes {
  static const String paymentRequired = 'MESSAGING_PAYMENT_REQUIRED';

  static const String windowClosed = 'MESSAGING_WINDOW_CLOSED';
}

abstract final class MessagingHistoryErrorCodes {
  /// `400`: `after=` çapası bu sohbette yok; istemci listeyi baştan çeker.
  static const String afterUnknown = 'MESSAGING_AFTER_UNKNOWN';
}
