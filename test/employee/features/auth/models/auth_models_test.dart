import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/agreement_version.dart';
import 'package:koala/employee/features/auth/models/auth_tokens.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/registration_verification.dart';
import 'package:koala/product/models/canonical_address.dart';

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

    test('alan hiç gelmezse doğrulama yanıtı reddedilir', () {
      expect(
        () => RegistrationVerification.fromJson({'setPasswordToken': 'jwt'}),
        throwsFormatException,
      );
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

    test(
      'iş arayan bayrağı açıkça false gelir, isteğe bağlı listeler boş kalır',
      () {
        final user = CurrentUser.fromJson({
          'isEmployer': false,
          'id': 'user-1',
          'firstName': 'Yakup',
          'lastName': 'Kahraman',
          'email': 'a@b.com',
        });

        expect(user.isEmployer, isFalse);
        expect(user.companies, isEmpty);
        expect(user.roles, isEmpty);
      },
    );

    test('profil alanları JSON gidiş dönüşünde korunur', () {
      final json = {
        'id': 'user-1',
        'firstName': 'Yakup',
        'lastName': 'Kahraman',
        'email': 'a@b.com',
        'birthDate': '1998-05-12',
        'isEmployer': false,
        'gender': 'FEMALE',
        'tcIdentityNumber': '11111111110',
        'about': 'Merhaba',
        'qualifications': 'Fotoğrafçı',
        'interests': 'Doğa',
        'address': {
          'id': 'address-1',
          'countryId': 'country-1',
          'countryName': 'TÜRKİYE',
          'countryCode': 'TR',
          'cityId': 'city-1',
          'cityName': 'İstanbul',
          'districtId': 'district-1',
          'districtName': 'Küçükçekmece',
          'components': {
            'neighborhood': 'Atakent Mahallesi',
            'thoroughfare': '221. Sokak',
            'buildingNumber': '4',
            'postalCode': '34307',
          },
          'position': {
            'latitude': 41.0,
            'longitude': 28.8,
            'source': 'USER_CONFIRMED_PIN',
          },
          'canonicalVersion': 1,
          'needsReview': false,
        },
      };

      final user = CurrentUser.fromJson(json);

      expect(user.birthDate, DateTime(1998, 5, 12));
      expect(user.gender, Gender.female);
      expect(user.about, 'Merhaba');
      expect(user.qualifications, 'Fotoğrafçı');
      expect(user.interests, 'Doğa');
      expect(user.address?.cityName, 'İstanbul');
      expect(CurrentUser.fromJson(user.toJson()).toJson(), user.toJson());
    });

    test('cinsiyet gelmezse ya da tanınmazsa belirtilmemiş sayılır', () {
      final base = {
        'isEmployer': false,
        'id': 'user-1',
        'firstName': 'Yakup',
        'lastName': 'Kahraman',
        'email': 'a@b.com',
      };

      expect(CurrentUser.fromJson(base).gender, Gender.notSpecified);
      expect(
        CurrentUser.fromJson({...base, 'gender': 'UZAYLI'}).gender,
        Gender.notSpecified,
      );
    });

    test('bozuk doğum tarihi çökme yerine null olur', () {
      final user = CurrentUser.fromJson({
        'id': 'user-1',
        'firstName': 'Yakup',
        'lastName': 'Kahraman',
        'email': 'a@b.com',
        'birthDate': 'tarih değil',
        'isEmployer': false,
      });

      expect(user.birthDate, isNull);
    });
  });

  group('CanonicalAddress', () {
    test('kısa etiket ilçe/il olarak kurulur', () {
      final address = CanonicalAddress.fromJson({
        'id': 'address-1',
        'countryId': 'country-1',
        'countryName': 'TÜRKİYE',
        'countryCode': 'TR',
        'cityId': 'city-1',
        'cityName': 'İstanbul',
        'districtId': 'district-1',
        'districtName': 'Küçükçekmece',
        'canonicalVersion': 1,
        'needsReview': false,
      });

      expect(address.shortLabel, 'Küçükçekmece/İstanbul');
    });

    test('yalnız biri doluysa tek başına döner', () {
      final address = CanonicalAddress.fromJson({
        'id': 'address-1',
        'countryId': 'country-1',
        'countryName': 'TÜRKİYE',
        'countryCode': 'TR',
        'cityId': 'city-1',
        'cityName': 'İstanbul',
        'districtId': 'district-1',
        'districtName': '',
        'canonicalVersion': 1,
        'needsReview': false,
      });

      expect(address.shortLabel, 'İstanbul');
    });

    test('ikisi de boşsa null döner; satır hiç çizilmemeli', () {
      final address = CanonicalAddress.fromJson({
        'id': 'address-1',
        'countryId': 'country-1',
        'countryName': '',
        'countryCode': 'TR',
        'cityId': 'city-1',
        'cityName': '',
        'districtId': 'district-1',
        'districtName': '',
        'canonicalVersion': 1,
        'needsReview': false,
      });

      expect(address.shortLabel, isNull);
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
