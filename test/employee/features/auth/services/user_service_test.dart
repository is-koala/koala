import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/models/canonical_address.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('Kullanıcı servisinde profil fotoğrafı yükleme', () {
    test('fotoğraf image parçasıyla multipart PUT gönderilir', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );
      final file = File('${Directory.systemTemp.path}/koala-avatar.jpg')
        ..writeAsBytesSync(const [1, 2, 3]);
      addTearDown(() => file.deleteSync());

      await UserService.withClient(api.client).uploadProfilePicture(file.path);

      final request = api.requests.single;
      expect(request.path, '/users/me/profile-picture');
      expect(request.method, 'PUT');
      expect((request.data as FormData).files.single.key, 'image');
    });
  });

  group('Kullanıcı servisinde özgeçmiş yükleme', () {
    test('CV file parçasıyla yüklenir ve özel dosya adresi döner', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': '/users/me/cv/file'},
        ),
      );
      final file = File('${Directory.systemTemp.path}/koala-cv.pdf')
        ..writeAsBytesSync(const [1, 2, 3]);
      addTearDown(() => file.deleteSync());

      final url = await UserService.withClient(api.client).uploadCv(file.path);

      final request = api.requests.single;
      expect(request.path, '/users/me/cv');
      expect(request.method, 'PUT');
      expect((request.data as FormData).files.single.key, 'file');
      expect(url, '/users/me/cv/file');
    });
  });

  group('UserService.fetchPublicProfile', () {
    test('başka bir kullanıcının profili çekiliyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'user_9',
              'firstName': 'Ayşe',
              'lastName': 'Yılmaz',
              'jobTitle': 'Barista',
              'cityName': 'Ankara',
              'districtName': 'Çankaya',
            },
          },
        ),
      );

      final profile = await UserService.withClient(
        api.client,
      ).fetchPublicProfile('user_9');

      expect(api.requests.single.path, '/users/user_9');
      expect(profile.jobTitle, 'Barista');
      expect(profile.locationLabel, 'Çankaya/Ankara');
    });
  });

  group('UserService.fetchCurrentUser', () {
    test('yanıt modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'user-1',
              'firstName': 'Yakup',
              'lastName': 'Kahraman',
              'email': 'a@b.com',
              'about': 'Fotoğrafçıyım',
              'qualifications': 'Fotoğrafçı',
              'birthDate': '1998-05-12',
              'gender': 'MALE',
              'isEmployer': true,
              'address': {
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
              },
            },
          },
        ),
      );

      final user = await UserService.withClient(api.client).fetchCurrentUser();

      expect(api.requests.single.path, '/users/me');
      expect(api.requests.single.method, 'GET');
      expect(user.fullName, 'Yakup Kahraman');
      expect(user.about, 'Fotoğrafçıyım');
      expect(user.gender, Gender.male);
      expect(user.birthDate, DateTime(1998, 5, 12));
      expect(user.isEmployer, isTrue);
      expect(user.address?.shortLabel, 'Küçükçekmece/İstanbul');
    });

    test('oturum düşmüşse ApiException olarak yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 401,
          body: {'success': false, 'message': 'Oturum bulunamadı'},
        ),
      );

      expect(
        () => UserService.withClient(api.client).fetchCurrentUser(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Oturum bulunamadı')
              .having((e) => e.type, 'type', ApiErrorType.unauthorized),
        ),
      );
    });
  });

  group('UserService.updateProfile', () {
    FakeApi buildApi({List<Map<String, dynamic>> pending = const []}) {
      return FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'user': {
                'id': 'user-1',
                'isEmployer': false,
                'firstName': 'Yakup',
                'lastName': 'Kahraman',
                'email': 'a@b.com',
              },
              'pendingVerifications': pending,
            },
          },
        ),
      );
    }

    test('yalnızca verilen alanlar gövdeye konur', () async {
      final api = buildApi();

      await UserService.withClient(api.client).updateProfile(about: 'Merhaba');

      final request = api.requests.single;
      expect(request.path, '/users/me');
      expect(request.method, 'PATCH');
      expect(request.data, {'about': 'Merhaba'});
    });

    test('jobTitle ve telefon gövdeye konur', () async {
      final api = buildApi();

      await UserService.withClient(
        api.client,
      ).updateProfile(jobTitle: 'Fotoğrafçı', phoneNumber: '5550000000');

      expect(api.requests.single.data, {
        'phoneNumber': '5550000000',
        'jobTitle': 'Fotoğrafçı',
      });
    });

    test('hiçbir alan verilmezse gövde boş gider', () async {
      final api = buildApi();

      await UserService.withClient(api.client).updateProfile();

      expect(api.requests.single.data, isEmpty);
    });

    test('doğum tarihi saatsiz ve birthdate adıyla gönderilir', () async {
      final api = buildApi();

      await UserService.withClient(api.client).updateProfile(
        birthDate: DateTime(1998, 5, 2, 13, 45),
        gender: Gender.female,
      );

      expect(api.requests.single.data, {
        'birthdate': '1998-05-02',
        'gender': 'FEMALE',
      });
    });

    test('boş metin gönderilir; alanı temizlemenin yolu bu', () async {
      final api = buildApi();

      await UserService.withClient(api.client).updateProfile(about: '');

      expect(api.requests.single.data, {'about': ''});
    });

    test('doğrulama bekleyen alanlar yanıttan okunur', () async {
      final api = buildApi(
        pending: [
          {
            'id': 'ver-1',
            'type': 'EMAIL',
            'sentTo': 'yeni@b.com',
            'message': 'Doğrulama gönderildi',
          },
        ],
      );

      final result = await UserService.withClient(
        api.client,
      ).updateProfile(email: 'yeni@b.com');

      expect(result.user.email, 'a@b.com');
      expect(result.pendingVerifications.single.isEmail, isTrue);
      expect(result.pendingVerifications.single.sentTo, 'yeni@b.com');
      expect(
        result.pendingVerifications.single.message,
        'Doğrulama gönderildi',
      );
    });
  });

  group('UserService.verifyIdentity', () {
    test('kimlik bilgileri doğru yola gider', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await UserService.withClient(api.client).verifyIdentity(
        firstName: 'Ada',
        lastName: 'Kaya',
        birthDate: DateTime(1998, 4, 7),
        tcIdentityNumber: '12345678950',
        tcDocumentNumber: 'A01B23456',
      );

      final request = api.requests.single;
      expect(request.path, '/users/me/identity-verification');
      expect(request.method, 'POST');
      // Sunucu `LocalDate` bekliyor; saatli gönderim reddedilirdi.
      expect((request.data as Map<String, dynamic>)['birthDate'], '1998-04-07');
    });

    test('bilgiler doğrulanamazsa hata yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {'success': false, 'message': 'Bilgiler doğrulanamadı'},
        ),
      );

      await expectLater(
        UserService.withClient(api.client).verifyIdentity(
          firstName: 'Ada',
          lastName: 'Kaya',
          birthDate: DateTime(1998, 4, 7),
          tcIdentityNumber: '12345678950',
          tcDocumentNumber: 'A01B23456',
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('UserService.changePassword', () {
    test('üç alan da PUT gövdesiyle parola ucuna gider', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await UserService.withClient(api.client).changePassword(
        currentPassword: 'EskiSifre1',
        newPassword: 'YeniSifre1',
        confirmNewPassword: 'YeniSifre1',
      );

      final request = api.requests.single;
      expect(request.path, '/users/me/password');
      expect(request.method, 'PUT');
      expect(request.data, {
        'currentPassword': 'EskiSifre1',
        'newPassword': 'YeniSifre1',
        'confirmNewPassword': 'YeniSifre1',
      });
    });

    // Sunucu mevcut parola yanlışken `ValidationException` fırlatıyor, yani
    // `400`. Controller'daki `@ApiResponse` `401` yazsa da davranış bu.
    test('mevcut parola yanlışsa sunucunun mesajıyla hata yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 400,
          body: {'success': false, 'message': 'Mevcut parola hatalı'},
        ),
      );

      await expectLater(
        UserService.withClient(api.client).changePassword(
          currentPassword: 'YanlisSifre1',
          newPassword: 'YeniSifre1',
          confirmNewPassword: 'YeniSifre1',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Mevcut parola hatalı')
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    // Belgelenen ama gerçekleşmeyen durum: `401` gelse bile bu uç için
    // "oturum düştü" demek değil, `statusCode` ile ayırt edilebilmeli.
    test('401 gelirse de mesaj ve durum kodu çağırana ulaşıyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 401,
          body: {'success': false, 'message': 'Mevcut parola hatalı'},
        ),
      );

      await expectLater(
        UserService.withClient(api.client).changePassword(
          currentPassword: 'YanlisSifre1',
          newPassword: 'YeniSifre1',
          confirmNewPassword: 'YeniSifre1',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Mevcut parola hatalı')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });

  group('UserService.updateAddress', () {
    test('adres PUT ile toptan yazılıyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'adr_1',
              'countryId': 'country-1',
              'countryName': 'TÜRKİYE',
              'countryCode': 'TR',
              'cityId': 'city-1',
              'cityName': 'Ankara',
              'districtId': 'district-1',
              'districtName': 'Çankaya',
              'canonicalVersion': 1,
              'needsReview': false,
            },
          },
        ),
      );

      final address = await UserService.withClient(api.client).updateAddress(
        const AddressWrite(
          countryId: 'country-1',
          cityId: 'city-1',
          districtId: 'district-1',
          components: AddressComponents(
            neighborhood: 'Kızılırmak Mahallesi',
            thoroughfare: '1443. Cadde',
            buildingNumber: '12',
            postalCode: '06510',
          ),
          position: AddressPosition(
            latitude: 39.9,
            longitude: 32.85,
            source: AddressPositionSource.userConfirmedPin,
          ),
        ),
      );

      final request = api.requests.single;
      expect(request.path, '/users/me/address');
      expect(request.method, 'PUT');
      expect(address.cityName, 'Ankara');
    });

    test('adres yalnız V2 alanlarıyla gönderiliyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'adr_1',
              'countryId': 'country-1',
              'countryName': 'TÜRKİYE',
              'countryCode': 'TR',
              'cityId': 'city-1',
              'cityName': 'İSTANBUL',
              'districtId': 'district-1',
              'districtName': 'KADIKÖY',
              'canonicalVersion': 1,
              'needsReview': false,
            },
          },
        ),
      );

      await UserService.withClient(api.client).updateAddress(
        const AddressWrite(
          countryId: 'country-1',
          cityId: 'city-1',
          districtId: 'district-1',
          components: AddressComponents(
            neighborhood: 'Caferağa Mahallesi',
            thoroughfare: 'Moda Caddesi',
            buildingNumber: '12',
            postalCode: '34710',
          ),
          position: AddressPosition(
            latitude: 40.982512,
            longitude: 29.025411,
            source: AddressPositionSource.userConfirmedPin,
          ),
        ),
      );

      final body = api.requests.single.data as Map<String, dynamic>;
      expect(body.keys, {
        'countryId',
        'cityId',
        'districtId',
        'components',
        'position',
      });
      expect((body['position'] as Map)['source'], 'USER_CONFIRMED_PIN');
      expect(body.containsKey('addressLine'), isFalse);
    });
  });

  group('UserService.updateProfile IBAN', () {
    // IBAN'ın ayrı bir ucu yok; sunucu bu uçtan alıp birincil hesaba yazıyor.
    test('IBAN verilince gövdeye ekleniyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'pendingVerifications': [],
              'user': {
                'id': 'user_1',
                'firstName': 'Ada',
                'lastName': 'Kaya',
                'isEmployer': false,
              },
            },
          },
        ),
      );

      await UserService.withClient(
        api.client,
      ).updateProfile(iban: 'TR330006100519786457841326');

      final body = api.requests.single.data as Map<String, dynamic>;
      expect(body['iban'], 'TR330006100519786457841326');
    });

    test('IBAN verilmezse gövdeye hiç konmuyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'pendingVerifications': [],
              'user': {
                'id': 'user_1',
                'firstName': 'Ada',
                'lastName': 'Kaya',
                'isEmployer': false,
              },
            },
          },
        ),
      );

      await UserService.withClient(api.client).updateProfile(about: 'Merhaba');

      final body = api.requests.single.data as Map<String, dynamic>;
      expect(body.containsKey('iban'), isFalse);
    });
  });
}
