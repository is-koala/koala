import 'package:koala/employee/features/auth/models/current_user.dart';

/// İlana başvurabilmek için karşılanması gereken şart.
///
/// Sunucu `POST /jobs/{id}/applications` isteğinde üçünü **bu sırayla**
/// kontrol ediyor (`JobApplicationManager.assertReadyToWork`) ve her biri
/// kendi `errorCode`'unu döndürüyor. Sıra keyfi değil, çalışanın düzeltme
/// sırası: kimliği doğrulanmadan adresi anlamsız, adresi olmadan ödeme
/// yapılamaz.
///
/// Şartlar, işçinin İyzico alt üye işyeri kaydının (`createSubMerchantDtoFor
/// Worker`) istedikleriyle birebir aynı; ayrışırlarsa hata başvuruda değil
/// kabul anında patlar.
enum ApplicationRequirement {
  identity(
    errorCode: 'APPLICANT_IDENTITY_NOT_VERIFIED',
    title: 'Kimliğini doğrula',
    description:
        'İşe başvurabilmen için kimlik bilgilerini doğrulaman gerekiyor.',
    actionLabel: 'Kimliğimi Doğrula',
    route: '/identity-verification',
  ),
  address(
    errorCode: 'APPLICANT_ADDRESS_REQUIRED',
    title: 'Adresini ekle',
    description: 'Sözleşme ve ödeme için adres bilgin gerekiyor.',
    actionLabel: 'Adresimi Ekle',
    route: '/address',
  ),
  bankAccount(
    errorCode: 'APPLICANT_BANK_ACCOUNT_REQUIRED',
    title: 'IBAN ekle',
    description:
        'Çalıştığın işin ücretini alabilmen için IBAN bilgin gerekiyor.',
    actionLabel: 'IBAN Ekle',
    route: '/settings/account-info',
  );

  const ApplicationRequirement({
    required this.errorCode,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.route,
  });

  /// Sunucunun döndürdüğü makine okunur kod.
  final String errorCode;

  final String title;
  final String description;
  final String actionLabel;

  /// Şartı karşılayan ekranın yolu.
  final String route;

  /// Sunucunun hata kodundan şartı bulur; tanımadığı kodda `null`.
  static ApplicationRequirement? fromErrorCode(String? errorCode) {
    if (errorCode == null) return null;

    for (final requirement in ApplicationRequirement.values) {
      if (requirement.errorCode == errorCode) return requirement;
    }
    return null;
  }
}

/// Kullanıcının başvuruya hazır olup olmadığı.
///
/// `/users/me` zaten üç bilgiyi de taşıyor (`identityVerified`, `address`,
/// `maskedIban`), o yüzden eksik şart başvuru gönderilmeden **önce**
/// söylenebiliyor. Sunucudan gelen hata yine de yakalanıyor: kullanıcı
/// başka bir cihazdan bilgisini silmiş olabilir.
class ApplicationReadiness {
  const ApplicationReadiness(this.missing);

  /// Karşılanmamış şartlar, sunucunun kontrol ettiği sırayla.
  final List<ApplicationRequirement> missing;

  bool get isReady => missing.isEmpty;

  /// Kullanıcının önce halletmesi gereken şart.
  ApplicationRequirement? get first => missing.isEmpty ? null : missing.first;

  factory ApplicationReadiness.of(CurrentUser? user) {
    if (user == null) return const ApplicationReadiness([]);

    return ApplicationReadiness([
      if (!user.identityVerified) ApplicationRequirement.identity,
      if (user.address == null) ApplicationRequirement.address,
      // Sunucu IBAN'ı maskeli döndürüyor; dolu olması hesabın var demek.
      if (user.maskedIban == null || user.maskedIban!.isEmpty)
        ApplicationRequirement.bankAccount,
    ]);
  }
}
