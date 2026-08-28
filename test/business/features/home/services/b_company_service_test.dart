import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/b_company.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';

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
      'cityName': 'Ankara',
      'districtName': 'Çankaya',
      'addressLine': 'Ziya Gökalp Cd. 45/A',
      'countryName': 'Türkiye',
    },
    'followerCount': 12,
  },
};

void main() {
  group('fetchCompany', () {
    test('şirket modele çevriliyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: _companyBody),
      );

      final company = await BCompanyService.withClient(
        api.client,
      ).fetchCompany('comp_1');

      expect(api.requests.single.path, '/companies/comp_1');
      expect(company.name, 'Kahve Durağı');
      expect(company.type, BCompanyType.limited);
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

      final company = await BCompanyService.withClient(
        api.client,
      ).fetchCompany('c');

      expect(company.type, BCompanyType.other);
    });

    test('onay bilgisi yanıtta olmadığı için varsayılan false', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: _companyBody),
      );

      final company = await BCompanyService.withClient(
        api.client,
      ).fetchCompany('comp_1');

      // `CompanyDto` `isApproved` döndürmüyor; değer `/users/me`'deki üyelik
      // kaydından besleniyor.
      expect(company.isApproved, isFalse);
      expect(company.copyWith(isApproved: true).isApproved, isTrue);
    });
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
