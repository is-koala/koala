import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/widgets/b_job_gallery_section.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/product/providers/job_gallery_provider.dart';
import 'package:koala/product/services/job_gallery_service.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/gallery_strip.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

Map<String, dynamic> _gallery(List<String> ids, {String? cover}) => {
  'success': true,
  'data': [
    for (final (index, id) in ids.indexed)
      {'id': id, 'url': 'not-a-url', 'sortOrder': index, 'cover': id == cover},
  ],
};

Future<(FakeApi, JobGalleryProvider)> _loadedProvider(
  WidgetTester tester, {
  List<String> ids = const ['img_1', 'img_2'],
  String? cover = 'img_1',
  List<String>? writeIds,
  String? writeCover,
}) async {
  final api = FakeApi(
    handler: (request) => FakeApiResponse(
      statusCode: 200,
      body: request.method == 'GET'
          ? _gallery(ids, cover: cover)
          : _gallery(writeIds ?? ids, cover: writeCover ?? cover),
    ),
  );
  final provider = JobGalleryProvider(
    service: JobGalleryService.withClient(api.client),
  );
  await tester.runAsync(() => provider.load('job_1'));
  return (api, provider);
}

void main() {
  testWidgets('yetkisiz kullanıcı galeriyi görür ama denetimleri görmez', (
    tester,
  ) async {
    final (_, provider) = await _loadedProvider(tester);
    await pumpInApp(
      tester,
      SingleChildScrollView(
        child: BJobGallerySection(
          jobId: 'job_1',
          canManage: false,
          provider: provider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GalleryStrip), findsOneWidget);
    expect(find.text('Görsel Yükle'), findsNothing);
    expect(find.text('Kapak Yap'), findsNothing);
    expect(find.text('Kaldır'), findsNothing);
  });

  testWidgets('on görselde yükleme ve şirketten seçme kapalıdır', (
    tester,
  ) async {
    final (_, provider) = await _loadedProvider(
      tester,
      ids: [for (var index = 0; index < 10; index++) 'img_$index'],
      cover: 'img_0',
    );
    await pumpInApp(
      tester,
      SingleChildScrollView(
        child: BJobGallerySection(
          jobId: 'job_1',
          canManage: true,
          provider: provider,
          companyImages: const [GalleryImage(id: 'company_img', url: '')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Görsel Yükle'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Şirketten Seç'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('kapak ve sıralama tam PUT ile yalnız bırakma anında gider', (
    tester,
  ) async {
    final (api, provider) = await _loadedProvider(
      tester,
      writeIds: const ['img_2', 'img_1'],
      writeCover: 'img_2',
    );
    await pumpInApp(
      tester,
      SingleChildScrollView(
        child: BJobGallerySection(
          jobId: 'job_1',
          canManage: true,
          provider: provider,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kapak Yap'));
    await tester.pumpAndSettle();
    expect(
      api.requests.where((request) => request.method == 'PUT'),
      hasLength(1),
    );
    expect(provider.images.first.id, 'img_2');
    expect(provider.images.first.isCover, isTrue);

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(0, 1);
    await tester.pumpAndSettle();

    final puts = api.requests.where((request) => request.method == 'PUT');
    expect(puts, hasLength(2));
    expect(((puts.last.data as Map)['images'] as List), hasLength(2));
  });

  testWidgets('şirket galerisinden seçim tam listeye ekleniyor', (
    tester,
  ) async {
    final (api, provider) = await _loadedProvider(
      tester,
      ids: const ['img_1'],
      writeIds: const ['img_1', 'company_img'],
    );
    await pumpInApp(
      tester,
      SingleChildScrollView(
        child: BJobGallerySection(
          jobId: 'job_1',
          canManage: true,
          provider: provider,
          companyImages: const [
            GalleryImage(
              id: 'company_img',
              url: 'not-a-url',
              isCover: true,
              caption: 'Mutfak',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Şirketten Seç'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomSheet), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    await tester.tap(find.text('Mutfak'));
    await tester.pumpAndSettle();

    expect(api.requests.last.method, 'PUT');
    expect(
      ((api.requests.last.data as Map)['images'] as List).map(
        (entry) => (entry as Map)['imageId'],
      ),
      ['img_1', 'company_img'],
    );
    expect(
      ((api.requests.last.data as Map)['images'] as List).map(
        (entry) => (entry as Map)['cover'],
      ),
      [true, false],
    );
  });

  testWidgets('390 piksel koyu temada yönetim taşmadan çiziliyor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, provider) = await _loadedProvider(tester);

    await pumpInApp(
      tester,
      SingleChildScrollView(
        child: BJobGallerySection(
          jobId: 'job_1',
          canManage: true,
          provider: provider,
        ),
      ),
      brightness: Brightness.dark,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('İlan Galerisi'), findsOneWidget);
  });
}
