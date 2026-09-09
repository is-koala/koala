import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
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

BCompanyProvider providerFor(FakeApi api) => BCompanyProvider(
  service: BCompanyService.withClient(api.client),
  // Şirketin okunması iki uygulamanın ortak servisinde.
  companyService: CompanyService.withClient(api.client),
);

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

    test('eski güncelleme yanıtı yeni hesabın şirketini ezmez', () async {
      final accountAUpdate = Completer<FakeApiResponse>();
      final api = FakeApi(
        handler: (options) {
          if (options.method == 'PATCH') return accountAUpdate.future;

          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': options.path.startsWith('/companies/')
                  ? companyJson(id: options.path.split('/').last)
                  : statsJson(),
            },
          );
        },
      );
      final provider = providerFor(api);
      await provider.load(userId: 'hesap_a', companyId: 'hesap_a');

      final accountAResult = provider.updateCompany(name: 'Eski şirket');
      await api.requestsReach(3);

      provider.clear();
      await provider.load(userId: 'hesap_b', companyId: 'hesap_b');

      accountAUpdate.complete(
        FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {...companyJson(id: 'hesap_a'), 'name': 'Eski şirket'},
          },
        ),
      );

      expect(await accountAResult, isFalse);
      expect(provider.company?.id, 'hesap_b');
      expect(provider.errorMessage, isNull);
    });
  });

  group('galeri', () {
    /// Şirket okumasını, galeri yazmasını ve istatistiği birlikte karşılar.
    FakeApi galleryApi({
      required FakeApiResponse Function() onWrite,
      List<Map<String, dynamic>> initialImages = const [],
    }) {
      return FakeApi(
        handler: (options) {
          if (options.path.contains('/images')) return onWrite();

          if (options.path.startsWith('/companies/')) {
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {...companyJson(), 'images': initialImages},
              },
            );
          }

          return FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': statsJson()},
          );
        },
      );
    }

    /// `postFile` dosyayı istekten **önce** okuyor: var olmayan bir yol
    /// `ApiException` değil `FileSystemException` fırlatır.
    String tempImage(String name) {
      final file = File('${Directory.systemTemp.path}/$name')
        ..writeAsBytesSync(const [1, 2, 3]);
      addTearDown(() => file.existsSync() ? file.deleteSync() : null);
      return file.path;
    }

    FakeApiResponse gallery(List<Map<String, dynamic>> images) {
      return FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': images},
      );
    }

    Map<String, dynamic> imageJson(
      String id, {
      int sortOrder = 0,
      bool cover = false,
    }) => {
      'id': id,
      'url': 'https://cdn.local/$id.png',
      'sortOrder': sortOrder,
      'cover': cover,
    };

    test('şirket yüklenince galeri gövdeden geliyor', () async {
      final provider = providerFor(
        galleryApi(
          onWrite: () => gallery(const []),
          initialImages: [imageJson('img_1', cover: true)],
        ),
      );

      await provider.load(userId: 'user_1', companyId: 'comp_1');

      // Ayrı bir `GET /companies/{id}/images` atılmıyor: şirket detayı
      // görselleri zaten taşıyor.
      expect(provider.galleryImages.map((image) => image.id), ['img_1']);
      expect(provider.canAddGalleryImage, isTrue);
    });

    test('ekleme sonrası liste sunucudan dönen sırayla tazeleniyor', () async {
      final api = galleryApi(
        onWrite: () => gallery([
          imageJson('img_1', cover: true),
          imageJson('img_2', sortOrder: 1),
        ]),
        initialImages: [imageJson('img_1', cover: true)],
      );
      final provider = providerFor(api);
      await provider.load(userId: 'user_1', companyId: 'comp_1');

      final added = await provider.addGalleryImage(
        tempImage('koala_gallery_add.png'),
      );

      expect(added, isTrue);
      expect(provider.galleryImages.map((image) => image.id), [
        'img_1',
        'img_2',
      ]);
      // `Company` değil `List<GalleryImageDto>` dönüyor; eldeki şirketin
      // geri kalanı korunuyor.
      expect(provider.company?.name, 'Kahve Durağı');
    });

    test('galeri doluyken ekleme düğmesi kapalı', () async {
      final provider = providerFor(
        galleryApi(
          onWrite: () => gallery(const []),
          initialImages: [
            for (var index = 0; index < 10; index++)
              imageJson('img_$index', sortOrder: index),
          ],
        ),
      );

      await provider.load(userId: 'user_1', companyId: 'comp_1');

      expect(provider.canAddGalleryImage, isFalse);
    });

    test('409 gelirse sunucunun mesajı taşınıyor', () async {
      final provider = providerFor(
        galleryApi(
          onWrite: () => const FakeApiResponse(
            statusCode: 409,
            body: {
              'success': false,
              'message': 'Galeri için izin verilen görsel sayısına ulaşıldı.',
            },
          ),
        ),
      );
      await provider.load(userId: 'user_1', companyId: 'comp_1');

      expect(
        await provider.addGalleryImage(tempImage('koala_gallery_409.png')),
        isFalse,
      );
      expect(
        provider.galleryErrorMessage,
        'Galeri için izin verilen görsel sayısına ulaşıldı.',
      );
    });

    test('sıralama galerinin tamamını tek PUT ile gönderiyor', () async {
      final api = galleryApi(
        onWrite: () => gallery([
          imageJson('img_2', cover: true),
          imageJson('img_1', sortOrder: 1),
        ]),
        initialImages: [
          imageJson('img_1', cover: true),
          imageJson('img_2', sortOrder: 1),
        ],
      );
      final provider = providerFor(api);
      await provider.load(userId: 'user_1', companyId: 'comp_1');

      final saved = await provider.replaceGallery(
        provider.galleryImages.reversed.toList(),
      );

      expect(saved, isTrue);
      final write = api.requests.last;
      expect(write.method, 'PUT');
      expect((write.data as Map)['images'], hasLength(2));
      expect(provider.galleryImages.first.id, 'img_2');
    });

    test('kapak sunucudan geliyor, istemci hesaplamıyor', () async {
      final api = galleryApi(
        // Silinen kapağın yerine sunucu kalanların ilkini kapak yaptı.
        onWrite: () => gallery([imageJson('img_2', cover: true)]),
        initialImages: [
          imageJson('img_1', cover: true),
          imageJson('img_2', sortOrder: 1),
        ],
      );
      final provider = providerFor(api);
      await provider.load(userId: 'user_1', companyId: 'comp_1');

      final removed = await provider.removeGalleryImage('img_1');

      expect(removed, isTrue);
      expect(api.requests.last.method, 'DELETE');
      expect(api.requests.last.path, '/companies/comp_1/images/img_1');
      expect(provider.galleryImages.single.isCover, isTrue);
    });

    test('şirket yokken galeri isteği atılmıyor', () async {
      final api = galleryApi(onWrite: () => gallery(const []));
      final provider = providerFor(api);
      await provider.load(userId: 'user_1');
      final before = api.requests.length;

      expect(await provider.removeGalleryImage('img_1'), isFalse);
      expect(api.requests, hasLength(before));
    });

    test('eski galeri hatası yeni hesabın durumuna taşınmaz', () async {
      final accountARemove = Completer<FakeApiResponse>();
      final api = FakeApi(
        handler: (options) {
          if (options.method == 'DELETE') return accountARemove.future;
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': options.path.startsWith('/companies/')
                  ? companyJson(id: options.path.split('/').last)
                  : statsJson(),
            },
          );
        },
      );
      final provider = providerFor(api);
      await provider.load(userId: 'hesap_a', companyId: 'hesap_a');

      final accountAResult = provider.removeGalleryImage('img_a');
      await api.requestsReach(3);

      provider.clear();
      await provider.load(userId: 'hesap_b', companyId: 'hesap_b');

      accountARemove.complete(
        const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Eski galeri hatası'},
        ),
      );

      expect(await accountAResult, isFalse);
      expect(provider.company?.id, 'hesap_b');
      expect(provider.galleryErrorMessage, isNull);
      expect(provider.isGalleryBusy, isFalse);
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

  test('geç eski yanıtlar yeni hesabın şirket durumunu ezmez', () async {
    final accountACompany = Completer<FakeApiResponse>();
    final accountAStats = Completer<FakeApiResponse>();
    final accountBCompany = Completer<FakeApiResponse>();
    final accountBStats = Completer<FakeApiResponse>();
    final api = FakeApi(
      handler: (options) {
        return switch (options.path) {
          '/companies/hesap_a' => accountACompany.future,
          '/users/hesap_a/employer-stats' => accountAStats.future,
          '/companies/hesap_b' => accountBCompany.future,
          '/users/hesap_b/employer-stats' => accountBStats.future,
          _ => throw StateError('Beklenmeyen istek: ${options.path}'),
        };
      },
    );
    final provider = providerFor(api);

    final accountALoad = provider.load(userId: 'hesap_a', companyId: 'hesap_a');
    await api.requestsReach(2);

    provider.clear();
    final accountBLoad = provider.load(userId: 'hesap_b', companyId: 'hesap_b');
    final bStarted = await Future.any([
      api.requestsReach(4).then((_) => true),
      accountBLoad.then((_) => false),
    ]);
    expect(bStarted, isTrue, reason: 'Yeni oturumun istekleri engellenmemeli');

    accountACompany.complete(
      FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': companyJson(id: 'hesap_a'),
        },
      ),
    );
    accountAStats.complete(
      const FakeApiResponse(
        statusCode: 500,
        body: {'success': false, 'message': 'Eski istatistik hatası'},
      ),
    );
    await accountALoad;

    expect(provider.company, isNull);
    expect(provider.stats, isNull);
    expect(provider.isLoading, isTrue);
    expect(provider.hasLoaded, isFalse);
    expect(provider.errorMessage, isNull);
    expect(provider.statsErrorMessage, isNull);

    accountBCompany.complete(
      FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': companyJson(id: 'hesap_b'),
        },
      ),
    );
    accountBStats.complete(
      FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': statsJson(jobsPosted: 22)},
      ),
    );
    await accountBLoad;

    expect(provider.company?.id, 'hesap_b');
    expect(provider.stats?.jobsPosted, 22);
    expect(provider.isLoading, isFalse);
    expect(provider.hasLoaded, isTrue);
    expect(provider.errorMessage, isNull);
    expect(provider.statsErrorMessage, isNull);
  });
}
