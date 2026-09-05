import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/user_address.dart';
import 'package:koala/employee/features/jobs/models/application_readiness.dart';

CurrentUser buildUser({
  bool identityVerified = true,
  bool hasAddress = true,
  String? maskedIban = 'TR** **** 1234',
}) {
  return CurrentUser(
    id: 'user_1',
    firstName: 'Ada',
    lastName: 'Kaya',
    email: 'ada@example.com',
    isEmployer: false,
    identityVerified: identityVerified,
    maskedIban: maskedIban,
    address: hasAddress ? const UserAddress(id: 'adr_1') : null,
  );
}

void main() {
  group('ApplicationReadiness.of', () {
    test('üç şart da tamamsa hazır', () {
      final readiness = ApplicationReadiness.of(buildUser());

      expect(readiness.isReady, isTrue);
      expect(readiness.missing, isEmpty);
      expect(readiness.first, isNull);
    });

    test('kimliği doğrulanmamış kullanıcı hazır değil', () {
      final readiness = ApplicationReadiness.of(
        buildUser(identityVerified: false),
      );

      expect(readiness.isReady, isFalse);
      expect(readiness.missing, contains(ApplicationRequirement.identity));
    });

    test('adresi olmayan kullanıcı hazır değil', () {
      final readiness = ApplicationReadiness.of(buildUser(hasAddress: false));

      expect(readiness.missing, contains(ApplicationRequirement.address));
    });

    test('IBAN yoksa hazır değil', () {
      expect(
        ApplicationReadiness.of(buildUser(maskedIban: null)).missing,
        contains(ApplicationRequirement.bankAccount),
      );
      expect(
        ApplicationReadiness.of(buildUser(maskedIban: '')).missing,
        contains(ApplicationRequirement.bankAccount),
      );
    });

    // Sıra sunucunun kontrol sırası: kimlik → adres → IBAN. Kullanıcıya
    // önce halledeceği adım gösterilmeli.
    test('eksikler sunucunun kontrol sırasıyla dizilir', () {
      final readiness = ApplicationReadiness.of(
        buildUser(identityVerified: false, hasAddress: false, maskedIban: null),
      );

      expect(readiness.missing, [
        ApplicationRequirement.identity,
        ApplicationRequirement.address,
        ApplicationRequirement.bankAccount,
      ]);
      expect(readiness.first, ApplicationRequirement.identity);
    });

    // Kullanıcı henüz yüklenmediyse ekran uyarı göstermemeli; eksik olduğu
    // bilinmiyor, yok sayılıyor.
    test('kullanıcı yoksa eksik üretilmiyor', () {
      expect(ApplicationReadiness.of(null).isReady, isTrue);
    });
  });

  group('ApplicationRequirement.fromErrorCode', () {
    test('IBAN eylemi kayıtlı hesap bilgileri rotasına gider', () {
      expect(ApplicationRequirement.bankAccount.route, '/account-info');
    });

    test('sunucunun kodları şartlara eşlenir', () {
      expect(
        ApplicationRequirement.fromErrorCode('APPLICANT_IDENTITY_NOT_VERIFIED'),
        ApplicationRequirement.identity,
      );
      expect(
        ApplicationRequirement.fromErrorCode('APPLICANT_ADDRESS_REQUIRED'),
        ApplicationRequirement.address,
      );
      expect(
        ApplicationRequirement.fromErrorCode('APPLICANT_BANK_ACCOUNT_REQUIRED'),
        ApplicationRequirement.bankAccount,
      );
    });

    test('tanınmayan ve boş kod null döner', () {
      expect(ApplicationRequirement.fromErrorCode('UZAYLI'), isNull);
      expect(ApplicationRequirement.fromErrorCode(null), isNull);
    });
  });
}
