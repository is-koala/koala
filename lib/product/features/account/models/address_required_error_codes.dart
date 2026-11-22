import 'package:koala/product/network/api_exception.dart';

/// Sunucunun "önce adresinizi ekleyin" kodları; ikisinin çözümü de kendi adres
/// ekranı. `backend_error_codes_test.dart` kataloğa karşı sabitliyor.
class AddressRequiredErrorCodes {
  const AddressRequiredErrorCodes._();

  /// Çalışan adressiz başvuramaz.
  static const String applicant = 'APPLICANT_ADDRESS_REQUIRED';

  /// İşverenin adresi yoksa ödeme oturumu başlamıyor; sunucunun mesajı ne
  /// yapılacağını söylemediği için doğrudan adres ekranına gidiliyor.
  static const String employer =
      'JOB_ASSIGNMENT_ADDRESS_NOT_PROVIDED_FOR_EMPLOYER';

  static const Set<String> _all = {applicant, employer};

  static bool matches(ApiException error) => _all.contains(error.errorCode);
}
