import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/product/models/canonical_address.dart';

import '../../../../support/fake_api.dart';

/// `CompanyDto` biçiminde tam bir şirket yanıtı.
const _companyBody = {
  'success': true,
  'data': {
    'id': 'comp_1',
    'name': 'Kahve Durağı',
    'email': 'iletisim@kahveduragi.com',
    'logoUrl': 'https://cdn.local/logo.png',
    'phoneNumber': '+90 312 555 0202',
    'website': 'kahveduragi.com',
    'description': 'Kızılay merkezde bir cafe.',
    'taxNumber': '2345678901',
    'type': 'LIMITED',
    'address': {
      'id': 'addr_1',
      'countryId': 'country-1',
      'cityName': 'Ankara',
      'cityId': 'city-1',
      'districtName': 'Çankaya',
      'districtId': 'district-1',
      'countryName': 'Türkiye',
      'countryCode': 'TR',
      'components': {
        'neighborhood': 'Kızılay Mahallesi',
        'thoroughfare': 'Ziya Gökalp Caddesi',
        'buildingNumber': '45/A',
        'postalCode': '06420',
      },
      'position': {
        'latitude': 39.9200,
        'longitude': 32.8500,
        'source': 'USER_CONFIRMED_PIN',
      },
      'displayAddress': 'Kızılay Mahallesi, Ziya Gökalp Caddesi No:45/A',
      'canonicalVersion': 1,
      'needsReview': false,
    },
    'followerCount': 12,
    'approved': true,
  },
};

void main() {
  group('Şirket oluşturma', () {
    test(
      'şirket ve yapılandırılmış adres multipart POST ile gönderiliyor',
      () async {
        final api = FakeApi(
          handler: (_) =>
              const FakeApiResponse(statusCode: 201, body: _companyBody),
        );

        await BCompanyService.withClient(api.client).createCompany(
          name: 'Moda Kahve Atölyesi',
          email: 'merhaba@modakahve.test',
          phoneNumber: '+905551112233',
          taxNumber: '1234567890',
          type: CompanyType.limited,
          address: const AddressWrite(
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
              latitude: 40.9819,
              longitude: 29.0263,
              source: AddressPositionSource.userConfirmedPin,
            ),
          ),
        );

        final request = api.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/companies');
        expect(request.contentType, startsWith('multipart/form-data'));

        final formData = request.data as FormData;
        final companyPart = formData.files.singleWhere(
          (part) => part.key == 'company',
        );
        final bytes = await companyPart.value
            .clone()
            .finalize()
            .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
        final company = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        expect(company['name'], 'Moda Kahve Atölyesi');
        expect(company['type'], 'LIMITED');
        expect(
          (company['address'] as Map<String, dynamic>)['districtId'],
          'district-1',
        );
      },
    );
  });

  group('updateCompany', () {
    test('PATCH atılıyor ve yalnızca verilen alanlar gönderiliyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: _companyBody),
      );

      await BCompanyService.withClient(
        api.client,
      ).updateCompany('comp_1', name: 'Yeni Ad', description: null);

      final request = api.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/companies/comp_1');
      final body = request.data as Map;
      expect(body['name'], 'Yeni Ad');
      // Boş bırakılan alan gövdeye girmiyor: sunucu dokunmadığı alanı
      // koruyor, boş metin göndermek onu silmek olurdu.
      expect(body.containsKey('description'), isFalse);
      expect(body.containsKey('taxNumber'), isFalse);
    });
  });

  group('logo', () {
    test('kaldırma DELETE atıyor ve şirketin yeni hâlini döndürüyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: _companyBody),
      );

      final company = await BCompanyService.withClient(
        api.client,
      ).removeLogo('comp_1');

      expect(api.requests.single.method, 'DELETE');
      expect(api.requests.single.path, '/companies/comp_1/logo');
      expect(company.name, 'Kahve Durağı');
    });

    test('yükleme çok parçalı PUT olarak gidiyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: _companyBody),
      );
      final file = File('${Directory.systemTemp.path}/koala_logo_test.png')
        ..writeAsBytesSync(const [1, 2, 3]);
      addTearDown(() => file.deleteSync());

      await BCompanyService.withClient(
        api.client,
      ).updateLogo('comp_1', file.path);

      final request = api.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/companies/comp_1/logo');
      expect(request.contentType, startsWith('multipart/form-data'));
      // Parçanın adı `logo`; sunucu `@RequestPart("logo")` bekliyor.
      expect((request.data as FormData).files.single.key, 'logo');
    });
  });

  group('fetchEmployerStats', () {
    test('sayılar modele çevriliyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'userId': 'user_1',
              'jobsPosted': 12,
              'completedJobs': 5,
              'averageRating': 4.6,
              'reviewCount': 8,
              'memberSince': '2026-01-15T10:00:00Z',
            },
          },
        ),
      );

      final stats = await BCompanyService.withClient(
        api.client,
      ).fetchEmployerStats('user_1');

      expect(api.requests.single.path, '/users/user_1/employer-stats');
      expect(stats.jobsPosted, 12);
      expect(stats.completedJobs, 5);
      expect(stats.hasRating, isTrue);
      expect(stats.memberSince?.year, 2026);
    });

    test('değerlendirme yoksa puan gösterilmiyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'userId': 'user_1', 'averageRating': 0, 'reviewCount': 0},
          },
        ),
      );

      final stats = await BCompanyService.withClient(
        api.client,
      ).fetchEmployerStats('user_1');

      // Puanı olmayan işverene "0.0" yazmak kötü puan almış gibi görünürdü.
      expect(stats.hasRating, isFalse);
    });
  });
}
