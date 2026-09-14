import 'package:koala/employee/features/chat/models/messaging_gate_error_codes.dart';

/// Bir atama üzerinden mesajlaşmanın neden açık ya da kapalı olduğu.
///
/// Backend `MessagingAvailabilityReason` karşılığı. Ürün kuralı: iş arayan
/// ile işveren, işveren ücreti emanete alana kadar mesajlaşamıyor; sohbet
/// ödemeyle kurulan ilan grubunda dönüyor ve iş bittikten 7 gün sonra
/// kapanıyor (is-koala/koala-backend#257).
enum MessagingAvailabilityReason {
  /// İşveren ödemeyi tamamlamadı: atama yok, `PENDING_COLLECTION` ya da
  /// `FAILED`. Sunucu bu hâlde `403 MESSAGING_PAYMENT_REQUIRED` döndürüyor.
  paymentRequired('PAYMENT_REQUIRED'),

  /// Sohbet penceresi kapandı: atama iptal ya da reddedildi, ödeme iade
  /// edildi ya da iş bitiminden 7 gün geçti. Sunucu
  /// `409 MESSAGING_WINDOW_CLOSED` döndürüyor.
  closed('CLOSED'),

  available('AVAILABLE');

  const MessagingAvailabilityReason(this.code);

  /// Sunucunun `messagingAvailableReason` alanındaki değer.
  final String code;

  /// Sunucudan gelen kodu çevirir; tanınmayan ya da eksik değerde `null`.
  static MessagingAvailabilityReason? fromCode(Object? value) {
    for (final reason in values) {
      if (reason.code == value) return reason;
    }
    return null;
  }
}

/// Bir atama için mesajlaşma kapısının durumu.
///
/// Sunucu iki alan gönderiyor: `messagingAvailable` (kapı) ve
/// `messagingAvailableReason` (açıklama). **Alanların yokluğu kapı kapalı
/// demek**: eski bir sunucuya karşı düğme görünmemeli, çünkü o sunucu da
/// sohbeti ödeme öncesi reddediyor — sadece bunu önceden söylemiyor. Bu
/// yüzden varsayılan [paymentRequired]; `null` ya da tanınmayan bir sebep
/// açık kapı sayılmıyor.
class MessagingAvailability {
  const MessagingAvailability._(this.reason);

  /// Kapı açık; sohbet düğmesi gösterilebilir.
  static const available = MessagingAvailability._(
    MessagingAvailabilityReason.available,
  );

  /// Ödeme bekleniyor. Alan gelmediğinde de bu varsayılıyor.
  static const paymentRequired = MessagingAvailability._(
    MessagingAvailabilityReason.paymentRequired,
  );

  /// Sohbet penceresi kapanmış.
  static const closed = MessagingAvailability._(
    MessagingAvailabilityReason.closed,
  );

  /// İş arayana gösterilen açıklama; sunucunun `messaging.payment.required`
  /// metniyle aynı.
  static const workerPaymentNote =
      'Mesajlaşma, işveren ödemeyi tamamladığında açılır.';

  /// İşverene gösterilen açıklama: ödemeyi tamamlayan taraf o.
  static const employerPaymentNote =
      'Ödemeyi tamamlayınca ekip sohbeti açılır.';

  /// Kapanmış sohbet; iki tarafta da aynı.
  static const closedNote = 'Bu sohbet kapandı';

  final MessagingAvailabilityReason reason;

  bool get isAvailable => reason == MessagingAvailabilityReason.available;

  bool get needsPayment =>
      reason == MessagingAvailabilityReason.paymentRequired;

  bool get isClosed => reason == MessagingAvailabilityReason.closed;

  /// Düğmenin yerine yazılacak kısa açıklama; kapı açıkken `null`.
  String? noteFor({required bool asEmployer}) {
    return switch (reason) {
      MessagingAvailabilityReason.available => null,
      MessagingAvailabilityReason.paymentRequired =>
        asEmployer ? employerPaymentNote : workerPaymentNote,
      MessagingAvailabilityReason.closed => closedNote,
    };
  }

  /// Atama DTO'sundan okur.
  ///
  /// `messagingAvailable` `true` ise kapı açık; değilse sebep okunuyor ve
  /// sebep yoksa, tanınmıyorsa ya da kapalı kapıyla çelişiyorsa
  /// [paymentRequired] sayılıyor.
  factory MessagingAvailability.fromJson(Map<String, dynamic> json) {
    if (json['messagingAvailable'] == true) return available;

    return switch (MessagingAvailabilityReason.fromCode(
      json['messagingAvailableReason'],
    )) {
      MessagingAvailabilityReason.closed => closed,
      _ => paymentRequired,
    };
  }

  /// Sunucunun kapı hatasını çevirir; kapıyla ilgisi olmayan kodda `null`.
  ///
  /// `403 MESSAGING_PAYMENT_REQUIRED` → [paymentRequired],
  /// `409 MESSAGING_WINDOW_CLOSED` → [closed] ([MessagingGateErrorCodes]).
  /// Kategori yetmiyor: aynı `403` engel (`messaging.blocked`) için de
  /// geliyor ve o ayrı bir ekran.
  static MessagingAvailability? fromErrorCode(String? errorCode) {
    return switch (errorCode) {
      MessagingGateErrorCodes.paymentRequired => paymentRequired,
      MessagingGateErrorCodes.windowClosed => closed,
      _ => null,
    };
  }
}
