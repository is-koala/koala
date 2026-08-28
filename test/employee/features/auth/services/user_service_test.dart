import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

void main() {
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
                'cityName': 'İstanbul',
                'districtName': 'Küçükçekmece',
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
}
