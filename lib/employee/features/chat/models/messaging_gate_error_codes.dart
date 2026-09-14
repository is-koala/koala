/// Sunucunun mesajlaşma kapısında döndürdüğü `errorCode` değerleri.
///
/// `POST /jobs/{jobId}/conversation` ve ikili sohbete
/// `POST /conversations/{id}/messages` bu kapıdan geçiyor. Kodlar mesaj
/// anahtarından türüyor (`{messaging.payment.required}` →
/// `MESSAGING_PAYMENT_REQUIRED`, `KoalaException.deriveErrorCode`); metne
/// değil koda bakılıyor.
///
/// Ayrı dosyada duruyor çünkü `test/support/backend_error_codes_test.dart`
/// bu dosyadaki her büyük harfli dizgeyi backend kataloğuyla karşılaştırıyor;
/// `messaging_availability.dart`'taki sebep kodları (`PAYMENT_REQUIRED` gibi)
/// hata kodu değil ve o karşılaştırmaya girmemeli.
abstract final class MessagingGateErrorCodes {
  /// `403` — işveren ödemeyi tamamlamadı.
  static const String paymentRequired = 'MESSAGING_PAYMENT_REQUIRED';

  /// `409` — sohbet penceresi kapandı.
  static const String windowClosed = 'MESSAGING_WINDOW_CLOSED';
}
