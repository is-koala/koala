import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/formatters/financial_failure_message.dart';

void main() {
  test('bilinen ödeme hata anahtarını eyleme dönük Türkçe metne çevirir', () {
    expect(
      FinancialFailureMessage.payment('{payment.3ds.verification.failed}'),
      '3D Secure doğrulaması tamamlanamadı. Lütfen tekrar dene.',
    );
  });

  test('tanınmayan sağlayıcı metnini ödeme yüzeyine sızdırmaz', () {
    expect(
      FinancialFailureMessage.payment('card bin=123456 rejected'),
      FinancialFailureMessage.paymentFallback,
    );
  });

  test('fraud filtresi reddini güvenli ve eyleme dönük açıklar', () {
    expect(
      FinancialFailureMessage.payment('{payment.fraud.review}'),
      'Ödeme güvenlik kontrolünde reddedildi. Destekle iletişime geçebilirsin.',
    );
  });

  test('bilinen payout anahtarını açık Türkçe metne çevirir', () {
    expect(
      FinancialFailureMessage.payout('{payout.settlement.failed}'),
      'Kazanç ödemesi tamamlanamadı. Destek ekibi işlemi inceleyecek.',
    );
  });
}
