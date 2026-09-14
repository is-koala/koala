import 'package:koala/product/network/api_exception.dart';

/// Sunucunun "önce adresinizi ekleyin" dediği `errorCode` değerleri.
///
/// Kod, `messages_tr.properties` anahtarından türüyor
/// (`test/support/backend_error_codes_test.dart` bunu kataloğa karşı
/// sabitliyor); yönlendirme mesaj metnine değil bu dizgelere bakıyor.
///
/// İki kod iki ayrı kapıdan geliyor ama çözümü tek: kullanıcının kendi
/// adres ekranı (`AccountRoutes.address`).
class AddressRequiredErrorCodes {
  const AddressRequiredErrorCodes._();

  /// `JobApplicationManager.assertReadyToWork`: çalışan adressiz başvuramaz.
  static const String applicant = 'APPLICANT_ADDRESS_REQUIRED';

  /// `JobAssignmentManager.initiatePaymentSession`: bireysel işverenin
  /// (ya da şirketinin) adresi yoksa İyzico alıcı kaydı kurulamıyor ve ödeme
  /// oturumu `400` ile başlamıyor. Sunucunun mesajı "İşverenin adres bilgisi
  /// eksik." — kullanıcıya ne yapacağını söylemediği için uygulama onu
  /// doğrudan adres ekranına götürüyor.
  static const String employer =
      'JOB_ASSIGNMENT_ADDRESS_NOT_PROVIDED_FOR_EMPLOYER';

  static const Set<String> _all = {applicant, employer};

  /// [error] adres eksikliğinden mi kaynaklanıyor.
  static bool matches(ApiException error) => _all.contains(error.errorCode);
}
