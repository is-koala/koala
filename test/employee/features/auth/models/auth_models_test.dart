import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/agreement_version.dart';
import 'package:koala/employee/features/auth/models/auth_tokens.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/registration_verification.dart';

void main() {
  group('AuthTokens', () {
    test('JSON gidiş dönüşü alanları korur', () {
      final json = {
        'token': 'access',
        'refreshToken': 'refresh',
        'refreshExpiresAt': '2026-09-26T10:00:00.000Z',
      };

      final tokens = AuthTokens.fromJson(json);

      expect(tokens.token, 'access');
      expect(tokens.refreshToken, 'refresh');
      expect(tokens.refreshExpiresAt, DateTime.utc(2026, 9, 26, 10));
      expect(AuthTokens.fromJson(tokens.toJson()).toJson(), tokens.toJson());
    });

    test('refreshExpiresAt yoksa null kalır', () {
      final tokens = AuthTokens.fromJson({
        'token': 'access',
        'refreshToken': 'refresh',
      });

      expect(tokens.refreshExpiresAt, isNull);
    });

    test('bozuk tarih null olur, hata fırlatmaz', () {
      final tokens = AuthTokens.fromJson({
        'token': 'access',
        'refreshToken': 'refresh',
        'refreshExpiresAt': 'tarih değil',
      });

      expect(tokens.refreshExpiresAt, isNull);
    });
  });

  group('RegistrationVerification', () {
    test('isEmployer alanı okunur', () {
      final verification = RegistrationVerification.fromJson({
        'setPasswordToken': 'jwt',
        'isEmployer': true,
      });

      expect(verification.setPasswordToken, 'jwt');
      expect(verification.isEmployer, isTrue);
    });

    test('alan hiç gelmezse çalışan varsayılır', () {
      final verification = RegistrationVerification.fromJson({
        'setPasswordToken': 'jwt',
      });

      expect(verification.isEmployer, isFalse);
    });
  });

  group('CurrentUser', () {
    test('JSON gidiş dönüşü alanları korur', () {
      final json = {
        'id': 'user-1',
        'firstName': 'Yakup',
        'lastName': 'Kahraman',
        'email': 'a@b.com',
        'profilePictureUrl': null,
        'phoneNumber': '5550000000',
        'isEmployer': true,
        'emailVerified': true,
        'phoneVerified': false,
        'identityVerified': false,
        'roles': ['ROLE_USER'],
        'companies': [
          {
            'companyId': 'company-1',
            'companyName': 'Koala A.Ş.',
            'role': 'OWNER',
            'approved': true,
          },
        ],
      };

      final user = CurrentUser.fromJson(json);

      expect(user.fullName, 'Yakup Kahraman');
      expect(user.isEmployer, isTrue);
      expect(user.emailVerified, isTrue);
      expect(user.identityVerified, isFalse);
      expect(user.roles, ['ROLE_USER']);
      expect(user.companies.single.companyName, 'Koala A.Ş.');
      expect(user.companies.single.approved, isTrue);
      expect(CurrentUser.fromJson(user.toJson()).toJson(), user.toJson());
    });

    test('bayrak hiç gelmezse çalışan varsayılır', () {
      final user = CurrentUser.fromJson({
        'id': 'user-1',
        'firstName': 'Yakup',
        'lastName': 'Kahraman',
        'email': 'a@b.com',
      });

      expect(user.isEmployer, isFalse);
      expect(user.companies, isEmpty);
      expect(user.roles, isEmpty);
    });
  });

  group('AgreementVersion', () {
    test('JSON gidiş dönüşü alanları korur', () {
      final json = {
        'id': 'agreement-1',
        'type': 'TERMS_OF_SERVICE',
        'version': '1.0',
        'locale': 'tr',
        'contentUrl': null,
        'mandatory': true,
        'effectiveFrom': '2026-08-27T00:00:00.000Z',
      };

      final agreement = AgreementVersion.fromJson(json);

      expect(agreement.type, AgreementType.termsOfService);
      expect(agreement.mandatory, isTrue);
      expect(agreement.effectiveFrom, DateTime.utc(2026, 8, 27));
      expect(
        AgreementVersion.fromJson(agreement.toJson()).toJson(),
        agreement.toJson(),
      );
    });

    test('bilinmeyen tip uygulamayı düşürmez', () {
      final agreement = AgreementVersion.fromJson({
        'id': 'agreement-2',
        'type': 'YENI_BIR_TIP',
        'mandatory': false,
      });

      expect(agreement.type, AgreementType.unknown);
      expect(agreement.type.consentLabel, isNotEmpty);
    });

    test('her tipin onay cümlesi var', () {
      for (final type in AgreementType.values) {
        expect(type.consentLabel, isNotEmpty, reason: type.code);
        expect(type.displayName, isNotEmpty, reason: type.code);
      }
    });
  });
}
