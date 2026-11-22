import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/product/features/account/account_routes.dart';
import 'package:koala/product/features/account/models/address_required_error_codes.dart';

/// Başvuru şartı. Sunucu üçünü **bu sırayla** kontrol ediyor ve her biri kendi
/// `errorCode`'unu döndürüyor; sıra düzeltme sırası. Şartlar İyzico alt üye
/// işyeri kaydınınkilerle aynı; ayrışırlarsa hata kabul anında patlar.
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
    errorCode: AddressRequiredErrorCodes.applicant,
    title: 'Adresini ekle',
    description: 'Sözleşme ve ödeme için adres bilgin gerekiyor.',
    actionLabel: 'Adresimi Ekle',
    route: AccountRoutes.address,
  ),
  bankAccount(
    errorCode: 'APPLICANT_BANK_ACCOUNT_REQUIRED',
    title: 'IBAN ekle',
    description:
        'Çalıştığın işin ücretini alabilmen için IBAN bilgin gerekiyor.',
    actionLabel: 'IBAN Ekle',
    route: AccountRoutes.accountInfo,
  );

  const ApplicationRequirement({
    required this.errorCode,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.route,
  });

  final String errorCode;

  final String title;
  final String description;
  final String actionLabel;

  final String route;

  /// Tanımadığı kodda `null`.
  static ApplicationRequirement? fromErrorCode(String? errorCode) {
    if (errorCode == null) return null;

    for (final requirement in ApplicationRequirement.values) {
      if (requirement.errorCode == errorCode) return requirement;
    }
    return null;
  }
}

/// Başvuruya hazır mı. `/users/me` üç bilgiyi de taşıdığı için eksik şart
/// gönderimden **önce** söylenir; sunucunun hatası yine yakalanır.
class ApplicationReadiness {
  const ApplicationReadiness(this.missing);

  /// Sunucunun kontrol sırasıyla.
  final List<ApplicationRequirement> missing;

  bool get isReady => missing.isEmpty;

  ApplicationRequirement? get first => missing.isEmpty ? null : missing.first;

  factory ApplicationReadiness.of(CurrentUser? user) {
    if (user == null) return const ApplicationReadiness([]);

    return ApplicationReadiness([
      if (!user.identityVerified) ApplicationRequirement.identity,
      if (user.address == null) ApplicationRequirement.address,
      // Maskeli IBAN dolu ise hesap var.
      if (user.maskedIban == null || user.maskedIban!.isEmpty)
        ApplicationRequirement.bankAccount,
    ]);
  }
}
