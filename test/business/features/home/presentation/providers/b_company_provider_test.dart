import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/auth/models/company_membership.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';

import '../../../../../support/fake_api.dart';

Map<String, dynamic> companyJson({String id = 'comp_1'}) => {
  'id': id,
  'name': 'Kahve Durağı',
  'email': 'iletisim@kahveduragi.com',
  'type': 'LIMITED',
};

Map<String, dynamic> statsJson({int jobsPosted = 12}) => {
  'userId': 'user_1',
  'jobsPosted': jobsPosted,
  'completedJobs': 5,
  'averageRating': 4.6,
  'reviewCount': 8,
};

/// Şirket ve istatistik uçlarını birlikte karşılayan sahte sunucu.
///
/// [companyStatus] ve [statsStatus] ayrı ayrı bozulabiliyor; iki isteğin
/// birbirini düşürmediğini doğrulamak için.
FakeApi buildApi({
  int companyStatus = 200,
  int statsStatus = 200,
  Map<String, dynamic>? company,
}) {
  return FakeApi(
    handler: (options) {
      if (options.path.startsWith('/companies/')) {
        return companyStatus == 200
            ? FakeApiResponse(
                statusCode: 200,
                body: {'success': true, 'data': company ?? companyJson()},
              )
            : const FakeApiResponse(
                statusCode: 500,
                body: {'success': false, 'message': 'Şirket alınamadı'},
              );
      }

      return statsStatus == 200
          ? FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': statsJson()},
            )
          : const FakeApiResponse(
              statusCode: 500,
              body: {'success': false, 'message': 'İstatistik alınamadı'},
            );
    },
  );
}

BCompanyProvider providerFor(FakeApi api) =>
    BCompanyProvider(service: BCompanyService.withClient(api.client));

CurrentUser buildUser({List<CompanyMembership> companies = const []}) {
  return CurrentUser(
    id: 'user_1',
    firstName: 'Ali',
    lastName: 'Veli',
    email: 'ali@example.com',
    isEmployer: true,
    companies: companies,
  );
}

void main() {
  group('load', () {
    test('şirket ve istatistikler birlikte çekiliyor', () async {
      final api = buildApi();
      final provider = providerFor(api);

      await provider.load(userId: 'user_1', companyId: 'comp_1');

      final paths = api.requests.map((r) => r.path).toList();
      expect(paths, contains('/companies/comp_1'));
      expect(paths, contains('/users/user_1/employer-stats'));
      expect(provider.company?.name, 'Kahve Durağı');
      expect(provider.stats?.jobsPosted, 12);
      expect(provider.errorMessage, isNull);
    });

    test('şirketi olmayan işverende yalnızca istatistik isteniyor', () async {
      final api = buildApi();
      final provider = providerFor(api);

      await provider.load(userId: 'user_1');

      expect(api.requests.single.path, '/users/user_1/employer-stats');
      // Şirketsizlik hata değil: bireysel işveren de ilan açabiliyor.
      expect(provider.company, isNull);
      expect(provider.errorMessage, isNull);
      expect(provider.stats, isNotNull);
    });

    test('onay bilgisi üyelikten geliyor', () async {
      final provider = providerFor(buildApi());

      await provider.load(
        userId: 'user_1',
        companyId: 'comp_1',
        isApproved: true,
      );

      // `CompanyDto` `isApproved` döndürmüyor; değer dışarıdan besleniyor.
      expect(provider.company?.isApproved, isTrue);
    });

    test('istatistik düşerse şirket yine de geliyor', () async {
      final provider = providerFor(buildApi(statsStatus: 500));

      await provider.load(userId: 'user_1', companyId: 'comp_1');

      expect(provider.company, isNotNull);
      expect(provider.errorMessage, isNull);
      expect(provider.statsErrorMessage, 'İstatistik alınamadı');
    });

    test('şirket düşerse mesaj taşınıyor ama istatistik geliyor', () async {
      final provider = providerFor(buildApi(companyStatus: 500));

      await provider.load(userId: 'user_1', companyId: 'comp_1');

      expect(provider.errorMessage, 'Şirket alınamadı');
      expect(provider.company, isNull);
      expect(provider.stats, isNotNull);
    });

    test('ikinci çağrı ağa çıkmıyor, force ile çıkıyor', () async {
      final api = buildApi();
      final provider = providerFor(api);

      await provider.load(userId: 'user_1', companyId: 'comp_1');
      expect(api.requests, hasLength(2));

      await provider.load(userId: 'user_1', companyId: 'comp_1');
      expect(api.requests, hasLength(2));

      await provider.load(userId: 'user_1', companyId: 'comp_1', force: true);
      expect(api.requests, hasLength(4));
    });

    test('başka bir şirket istenince yeniden çekiliyor', () async {
      final api = buildApi();
      final provider = providerFor(api);

      await provider.load(userId: 'user_1', companyId: 'comp_1');
      await provider.load(userId: 'user_1', companyId: 'comp_2');

      expect(api.requests.map((r) => r.path), contains('/companies/comp_2'));
    });
  });

  group('loadFor', () {
    test('onay bekleyen şirket de yükleniyor', () async {
      final api = buildApi();
      final provider = providerFor(api);

      await provider.loadFor(
        buildUser(
          companies: const [
            CompanyMembership(
              companyId: 'comp_1',
              companyName: 'Kahve Durağı',
              approved: false,
            ),
          ],
        ),
      );

      // `activeCompany` onaysızı elemiyor ama profil onu da göstermeli;
      // yoksa kullanıcı kurduğu şirketi hiç göremez.
      expect(api.requests.map((r) => r.path), contains('/companies/comp_1'));
      expect(provider.company?.isApproved, isFalse);
    });

    test('şirket üyeliği yoksa yalnızca istatistik isteniyor', () async {
      final api = buildApi();
      final provider = providerFor(api);

      await provider.loadFor(buildUser());

      expect(api.requests.single.path, '/users/user_1/employer-stats');
    });
  });

  group('updateCompany', () {
    test('başarılı güncellemede eldeki kayıt değişiyor', () async {
      final api = FakeApi(
        handler: (options) {
          if (options.method == 'PATCH') {
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {...companyJson(), 'name': 'Yeni Ad'},
              },
            );
          }
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': options.path.startsWith('/companies/')
                  ? companyJson()
                  : statsJson(),
            },
          );
        },
      );
      final provider = providerFor(api);
      await provider.load(
        userId: 'user_1',
        companyId: 'comp_1',
        isApproved: true,
      );

      final saved = await provider.updateCompany(name: 'Yeni Ad');

      expect(saved, isTrue);
      expect(provider.company?.name, 'Yeni Ad');
      // Onay bilgisi yanıtta yok; eldeki değer korunmalı.
      expect(provider.company?.isApproved, isTrue);
    });

    test('şirket yokken güncelleme istek atmıyor', () async {
      final api = buildApi();
      final provider = providerFor(api);
      await provider.load(userId: 'user_1');
      final before = api.requests.length;

      expect(await provider.updateCompany(name: 'X'), isFalse);
      expect(api.requests, hasLength(before));
    });

    test('sunucu reddederse mesaj taşınıyor', () async {
      final api = FakeApi(
        handler: (options) {
          if (options.method == 'PATCH') {
            return const FakeApiResponse(
              statusCode: 400,
              body: {'success': false, 'message': 'E-posta geçersiz'},
            );
          }
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': options.path.startsWith('/companies/')
                  ? companyJson()
                  : statsJson(),
            },
          );
        },
      );
      final provider = providerFor(api);
      await provider.load(userId: 'user_1', companyId: 'comp_1');

      expect(await provider.updateCompany(email: 'bozuk'), isFalse);
      expect(provider.errorMessage, 'E-posta geçersiz');
      expect(provider.company?.name, 'Kahve Durağı');
    });
  });

  test('clear çıkışta veriyi düşürüyor', () async {
    final provider = providerFor(buildApi());
    await provider.load(userId: 'user_1', companyId: 'comp_1');

    provider.clear();

    expect(provider.company, isNull);
    expect(provider.stats, isNull);
    expect(provider.hasLoaded, isFalse);
  });
}
