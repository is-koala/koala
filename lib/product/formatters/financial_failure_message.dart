/// Backend'in kalıcı finansal hata anahtarlarını kullanıcıya güvenli Türkçe
/// metin olarak sunar. Sağlayıcıdan veya bankadan gelen tanınmayan ham metin
/// hiçbir zaman ekrana taşınmaz.
abstract final class FinancialFailureMessage {
  static const paymentFallback = 'Ödeme tamamlanamadı. Lütfen tekrar dene.';
  static const payoutFallback =
      'Kazanç ödemesi tamamlanamadı. Lütfen destekle iletişime geç.';

  static const _payments = <String, String>{
    '{payment.initiation.failed}': 'Ödeme başlatılamadı. Lütfen tekrar dene.',
    '{payment.3ds.verification.failed}':
        '3D Secure doğrulaması tamamlanamadı. Lütfen tekrar dene.',
    '{payment.provider.unavailable}':
        'Ödeme sağlayıcısına şu anda ulaşılamıyor. Lütfen tekrar dene.',
    '{payment.provider.rejected}':
        'Ödeme sağlayıcısı işlemi reddetti. Başka bir yöntem deneyebilirsin.',
    '{payment.fraud.review}':
        'Ödeme güvenlik kontrolünde reddedildi. Destekle iletişime geçebilirsin.',
    'paymentStatus=FAILURE':
        'Ödeme sağlayıcı tarafından tamamlanmadı. Lütfen tekrar dene.',
  };

  static const _payouts = <String, String>{
    '{payout.settlement.failed}':
        'Kazanç ödemesi tamamlanamadı. Destek ekibi işlemi inceleyecek.',
  };

  static String payment(String? reason) => _payments[reason] ?? paymentFallback;

  static String payout(String? reason) => _payouts[reason] ?? payoutFallback;
}
