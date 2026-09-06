import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/job_gallery_service.dart';

import '../../support/fake_api.dart';

const _galleryBody = {
  'success': true,
  'data': [
    {
      'id': 'img_1',
      'url': 'https://cdn.local/1.png',
      'sortOrder': 0,
      'cover': true,
      'caption': null,
    },
    {
      'id': 'img_2',
      'url': 'https://cdn.local/2.png',
      'sortOrder': 1,
      'cover': false,
      'caption': 'Mutfak',
    },
  ],
};

void main() {
  test('GET ilan galerisini sunucu sırasıyla döndürüyor', () async {
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 200, body: _galleryBody),
    );

    final images = await JobGalleryService.withClient(
      api.client,
    ).fetchGallery('job_1');

    expect(api.requests.single.method, 'GET');
    expect(api.requests.single.path, '/jobs/job_1/images');
    expect(images.map((image) => image.id), ['img_1', 'img_2']);
  });

  test('POST görseli image adlı multipart parça olarak gönderiyor', () async {
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 201, body: _galleryBody),
    );
    final file = File('${Directory.systemTemp.path}/koala_job_gallery.png')
      ..writeAsBytesSync(const [1, 2, 3]);
    addTearDown(() => file.deleteSync());

    await JobGalleryService.withClient(api.client).addImage('job_1', file.path);

    final request = api.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/jobs/job_1/images');
    expect(request.contentType, startsWith('multipart/form-data'));
    expect((request.data as FormData).files.single.key, 'image');
  });

  test('PUT galerinin tamamını listedeki sırayla gönderiyor', () async {
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 200, body: _galleryBody),
    );

    await JobGalleryService.withClient(
      api.client,
    ).replaceGallery('job_1', const [
      GalleryImage(id: 'img_2', url: '', sortOrder: 8, caption: 'Mutfak'),
      GalleryImage(id: 'img_1', url: '', isCover: true),
    ]);

    final request = api.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/jobs/job_1/images');
    expect((request.data as Map)['images'], [
      {'imageId': 'img_2', 'sortOrder': 0, 'cover': false, 'caption': 'Mutfak'},
      {'imageId': 'img_1', 'sortOrder': 1, 'cover': true, 'caption': null},
    ]);
  });

  test('DELETE medya kimliğiyle gider ve sunucu listesini döndürür', () async {
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 200, body: _galleryBody),
    );

    final images = await JobGalleryService.withClient(
      api.client,
    ).removeImage('job_1', 'img_3');

    expect(api.requests.single.method, 'DELETE');
    expect(api.requests.single.path, '/jobs/job_1/images/img_3');
    expect(images, hasLength(2));
  });

  for (final (status, type) in [
    (404, ApiErrorType.notFound),
    (409, ApiErrorType.conflict),
  ]) {
    test('$status sunucu mesajını koruyor', () async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: status,
          body: {
            'success': false,
            'message': status == 404
                ? 'İlan ya da görsel bulunamadı.'
                : 'Galeri sınırına ulaşıldı.',
          },
        ),
      );

      await expectLater(
        JobGalleryService.withClient(
          api.client,
        ).replaceGallery('job_1', const [GalleryImage(id: 'img_9', url: '')]),
        throwsA(
          isA<ApiException>()
              .having((error) => error.type, 'type', type)
              .having((error) => error.message, 'message', contains('.')),
        ),
      );
    });
  }
}
