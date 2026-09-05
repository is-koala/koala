import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';

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
      'countryName': 'Türkiye',
      'countryCode': 'TR',
      'cityId': 'city-1',
      'cityName': 'Ankara',
      'districtId': 'district-1',
      'districtName': 'Çankaya',
      'components': {
        'neighborhood': 'Kızılay Mahallesi',
        'thoroughfare': 'Ziya Gökalp Caddesi',
        'buildingNumber': '45/A',
        'postalCode': '06420',
      },
      'position': {
        'latitude': 39.92,
        'longitude': 32.85,
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
  group('fetchCompany', () {
    test('şirket modele çevriliyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: _companyBody),
      );

      final company = await CompanyService.withClient(
        api.client,
      ).fetchCompany('comp_1');

      expect(api.requests.single.path, '/companies/comp_1');
      expect(company.name, 'Kahve Durağı');
      expect(company.type, CompanyType.limited);
      expect(company.address?.cityName, 'Ankara');
      expect(company.followerCount, 12);
    });

    test('tanınmayan şirket türü "Diğer"e düşüyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'id': 'c', 'name': 'X', 'type': 'KOOPERATIF'},
          },
        ),
      );

      final company = await CompanyService.withClient(
        api.client,
      ).fetchCompany('c');

      expect(company.type, CompanyType.other);
    });

    test('onay bilgisi `approved` anahtarından okunuyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: _companyBody),
      );

      final company = await CompanyService.withClient(
        api.client,
      ).fetchCompany('comp_1');

      // Sunucudaki alan adı `approved`; `isApproved` okunursa sessizce
      // "onay bekliyor" görünürdü.
      expect(company.isApproved, isTrue);
    });

    test('onay alanı hiç gelmezse false', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'id': 'c', 'name': 'X'},
          },
        ),
      );

      final company = await CompanyService.withClient(
        api.client,
      ).fetchCompany('c');

      expect(company.isApproved, isFalse);
      expect(company.copyWith(isApproved: true).isApproved, isTrue);
    });
  });

  group('follow / unfollow', () {
    test('takip POST, bırakma DELETE atıyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );
      final service = CompanyService.withClient(api.client);

      await service.follow('comp_1');
      await service.unfollow('comp_1');

      expect(api.requests.first.path, '/companies/comp_1/follow');
      expect(api.requests.first.method, 'POST');
      expect(api.requests.last.path, '/companies/comp_1/follow');
      expect(api.requests.last.method, 'DELETE');
    });
  });

  group('galeri ve takip durumu', () {
    // Şirket detayı görselleri ve takip durumunu gövdesinde taşıyor; ikinci
    // bir istek atmaya gerek yok.
    test('görseller ve takip bilgisi aynı yanıttan okunuyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'c',
              'name': 'X',
              'following': true,
              'images': [
                {'id': 'i1', 'url': 'https://cdn/1.png', 'cover': false},
                {'id': 'i2', 'url': 'https://cdn/2.png', 'cover': true},
              ],
            },
          },
        ),
      );

      final company = await CompanyService.withClient(
        api.client,
      ).fetchCompany('c');

      expect(api.requests, hasLength(1));
      expect(company.isFollowing, isTrue);
      expect(company.images, hasLength(2));
      expect(company.coverImage?.id, 'i2');
    });

    test('kapak işaretli görsel yoksa ilki kapak sayılıyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'c',
              'name': 'X',
              'images': [
                {'id': 'i1', 'url': 'https://cdn/1.png'},
              ],
            },
          },
        ),
      );

      final company = await CompanyService.withClient(
        api.client,
      ).fetchCompany('c');

      expect(company.coverImage?.id, 'i1');
    });

    test('görseli olmayan şirkette kapak null', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'id': 'c', 'name': 'X'},
          },
        ),
      );

      final company = await CompanyService.withClient(
        api.client,
      ).fetchCompany('c');

      expect(company.images, isEmpty);
      expect(company.coverImage, isNull);
      expect(company.isFollowing, isFalse);
    });
  });
}
