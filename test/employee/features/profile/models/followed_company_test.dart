import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/profile/models/followed_company.dart';

Map<String, dynamic> companyBody({String? logoUrl = 'https://cdn/l.png'}) {
  return {
    'companyId': 'cmp_1',
    'name': 'Koala Kafe',
    'logoUrl': logoUrl,
    'description': 'Kadıköy',
    'followerCount': 42,
    'followedAt': '2026-08-01T10:00:00Z',
  };
}

void main() {
  group('FollowedCompany', () {
    // Kimlik alanı `id` değil `companyId`; şirketin tam DTO'sundan farklı.
    test('sunucu gövdesi modele çevrilir', () {
      final company = FollowedCompany.fromJson(companyBody());

      expect(company.companyId, 'cmp_1');
      expect(company.name, 'Koala Kafe');
      expect(company.followerCount, 42);
      expect(company.followedAt, isNotNull);
    });

    test('logosuz şirket hata değil', () {
      expect(
        FollowedCompany.fromJson(companyBody(logoUrl: null)).logoUrl,
        isNull,
      );
    });
  });

  group('FollowedCompanyPage', () {
    test('sayfalı yanıt ayrıştırılır', () {
      final page = FollowedCompanyPage.fromJson({
        'content': [companyBody()],
        'page': 0,
        'totalElements': 1,
        'last': false,
      });

      expect(page.companies, hasLength(1));
      expect(page.last, isFalse);
      expect(page.totalElements, 1);
    });

    test('boş içerik hata değil', () {
      expect(FollowedCompanyPage.fromJson({'content': []}).companies, isEmpty);
    });
  });
}
