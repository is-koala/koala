import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/product/providers/job_gallery_provider.dart';
import 'package:koala/product/services/job_gallery_service.dart';

import '../../support/fake_api.dart';

Map<String, dynamic> galleryBody(List<String> ids, {String? coverId}) => {
  'success': true,
  'data': [
    for (final (index, id) in ids.indexed)
      {
        'id': id,
        'url': 'https://cdn.local/$id.png',
        'sortOrder': index,
        'cover': id == coverId,
      },
  ],
};

void main() {
  test('yükleme boş galeriyi hata durumundan ayırıyor', () async {
    final api = FakeApi(
      handler: (_) =>
          FakeApiResponse(statusCode: 200, body: galleryBody(const [])),
    );
    final provider = JobGalleryProvider(
      service: JobGalleryService.withClient(api.client),
    );

    await provider.load('job_1');

    expect(provider.isLoadedFor('job_1'), isTrue);
    expect(provider.isEmpty, isTrue);
    expect(provider.errorMessage, isNull);
  });

  test('yazma yanıtı yerel tahmin yerine tek doğru kaynak oluyor', () async {
    var writes = 0;
    final api = FakeApi(
      handler: (request) {
        if (request.method == 'GET') {
          return FakeApiResponse(
            statusCode: 200,
            body: galleryBody(['img_1', 'img_2'], coverId: 'img_1'),
          );
        }
        writes++;
        return FakeApiResponse(
          statusCode: 200,
          body: galleryBody(['img_2', 'img_1'], coverId: 'img_2'),
        );
      },
    );
    final provider = JobGalleryProvider(
      service: JobGalleryService.withClient(api.client),
    );
    await provider.load('job_1');

    final saved = await provider.replaceGallery(
      provider.images.reversed.toList(),
    );

    expect(saved, isTrue);
    expect(writes, 1);
    expect(provider.images.map((image) => image.id), ['img_2', 'img_1']);
    expect(provider.images.singleWhere((image) => image.isCover).id, 'img_2');
  });

  test('yükleme tamamlanmadan yazma isteği çıkmıyor', () async {
    final response = Completer<FakeApiResponse>();
    final api = FakeApi(handler: (_) => response.future);
    final provider = JobGalleryProvider(
      service: JobGalleryService.withClient(api.client),
    );

    final loading = provider.load('job_1');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(await provider.replaceGallery(const []), isFalse);
    expect(api.requests, hasLength(1));

    response.complete(
      FakeApiResponse(statusCode: 200, body: galleryBody(const [])),
    );
    await loading;
  });

  test('409 mesajını taşır ve eldeki galeriyi korur', () async {
    final api = FakeApi(
      handler: (request) => request.method == 'GET'
          ? FakeApiResponse(
              statusCode: 200,
              body: galleryBody(['img_1'], coverId: 'img_1'),
            )
          : const FakeApiResponse(
              statusCode: 409,
              body: {'success': false, 'message': 'Galeri sınırına ulaşıldı.'},
            ),
    );
    final provider = JobGalleryProvider(
      service: JobGalleryService.withClient(api.client),
    );
    await provider.load('job_1');
    final file = File('${Directory.systemTemp.path}/koala_job_limit.png')
      ..writeAsBytesSync(const [1]);
    addTearDown(() => file.deleteSync());

    expect(await provider.addImage(file.path), isFalse);
    expect(provider.errorMessage, 'Galeri sınırına ulaşıldı.');
    expect(provider.images.single.id, 'img_1');
  });

  test('başarısız ilk yüklemeden sonra mutasyon kapalı kalır', () async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 404,
        body: {'success': false, 'message': 'İlan bulunamadı.'},
      ),
    );
    final provider = JobGalleryProvider(
      service: JobGalleryService.withClient(api.client),
    );
    await provider.load('job_1');

    expect(
      await provider.replaceGallery(const [GalleryImage(id: 'img_1', url: '')]),
      isFalse,
    );
    expect(api.requests, hasLength(1));
  });

  test('on bir görsel varken on birinci yükleme ağa çıkmaz', () async {
    final api = FakeApi(
      handler: (_) => FakeApiResponse(
        statusCode: 200,
        body: galleryBody([
          for (var index = 0; index < 10; index++) 'img_$index',
        ]),
      ),
    );
    final provider = JobGalleryProvider(
      service: JobGalleryService.withClient(api.client),
    );
    await provider.load('job_1');

    expect(await provider.addImage('/tmp/new.png'), isFalse);
    expect(api.requests, hasLength(1));
  });

  test('şirket görseli de tam PUT listesine eklenebiliyor', () async {
    final api = FakeApi(
      handler: (request) => request.method == 'GET'
          ? FakeApiResponse(statusCode: 200, body: galleryBody(['img_1']))
          : FakeApiResponse(
              statusCode: 200,
              body: galleryBody(['img_1', 'company_img']),
            ),
    );
    final provider = JobGalleryProvider(
      service: JobGalleryService.withClient(api.client),
    );
    await provider.load('job_1');

    await provider.replaceGallery([
      ...provider.images,
      const GalleryImage(id: 'company_img', url: 'company.png'),
    ]);

    final entries = (api.requests.last.data as Map)['images'] as List;
    expect(entries.map((entry) => (entry as Map)['imageId']), [
      'img_1',
      'company_img',
    ]);
  });
}
