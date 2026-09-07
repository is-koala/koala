import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/employee/features/home/presentation/pages/explore_pages/list_explore_page.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/presentation/providers/job_search_provider.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:provider/provider.dart';

import '../../../../../../support/fake_api.dart';
import '../../../../../../support/pump.dart';

Map<String, dynamic> _job(String id) => {
  'id': id,
  'title': 'İlan $id',
  'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
  'type': 'ONE_TIME',
  'salaryType': 'DAILY',
  'salary': 800,
  'status': 'OPEN',
  'cityName': 'Ankara',
  'districtName': 'Kızılay',
};

Map<String, dynamic> _pageBody(List<String> ids, {required bool last}) => {
  'success': true,
  'data': {
    'content': [for (final id in ids) _job(id)],
    'page': ids.isEmpty ? 0 : int.parse(ids.first.split('-').first) ~/ 20,
    'size': 20,
    'totalElements': ids.length,
    'totalPages': last ? 1 : 2,
    'first': true,
    'last': last,
  },
};

/// `/jobs` isteklerini sayfa numarasına göre karşılayan sahte sunucu;
/// kategori ucu her zaman boş liste döndürüyor.
FakeApi _api(Map<int, Map<String, dynamic>> pages) {
  return FakeApi(
    handler: (RequestOptions options) {
      if (options.path.contains('job-categories')) {
        return const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        );
      }
      final requested = options.queryParameters['page'] as int? ?? 0;
      final body = pages[requested];
      if (body == null) {
        return const FakeApiResponse(
          statusCode: 500,
          body: {'success': false, 'message': 'Beklenmeyen sayfa'},
        );
      }
      return FakeApiResponse(statusCode: 200, body: body);
    },
  );
}

/// `/jobs` isteklerinin sorgu parametreleri, sırayla.
List<Map<String, dynamic>> jobQueries(FakeApi api) => [
  for (final request in api.requests)
    if (!request.path.contains('job-categories')) request.queryParameters,
];

Future<void> pumpPage(
  WidgetTester tester,
  FakeApi api, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpInApp(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              JobSearchProvider(service: JobService.withClient(api.client)),
        ),
        ChangeNotifierProvider(
          create: (_) => JobCategoryProvider(
            service: JobCategoryService.withClient(api.client),
          ),
        ),
      ],
      child: ListExplorePage(key: UniqueKey()),
    ),
    brightness: brightness,
  );
  await tester.pumpAndSettle();
}

List<String> _ids(int from, int count) => [
  for (var i = from; i < from + count; i++) '$i-ilan',
];

void main() {
  testWidgets('dibe yaklaşınca sonraki sayfa isteniyor', (tester) async {
    final api = _api({
      0: _pageBody(_ids(0, 20), last: false),
      1: _pageBody(_ids(20, 5), last: true),
    });

    await pumpPage(tester, api);

    expect(jobQueries(api).length, 1);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(jobQueries(api).map((query) => query['page']), [0, 1]);

    // 21. ilan yalnızca ikinci sayfa geldiği için var.
    await tester.scrollUntilVisible(
      find.text('İlan 20-ilan'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('İlan 20-ilan'), findsOneWidget);
  });

  testWidgets('son sayfada kaydırmak yeni istek doğurmuyor', (tester) async {
    final api = _api({0: _pageBody(_ids(0, 20), last: true)});

    await pumpPage(tester, api);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(jobQueries(api).length, 1);
  });

  testWidgets('arama her tuşta değil, yazım durunca sunucuya gidiyor', (
    tester,
  ) async {
    final api = _api({0: _pageBody(const [], last: true)});

    await pumpPage(tester, api);
    expect(jobQueries(api).length, 1);

    await tester.enterText(find.byType(TextField), 'g');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'ga');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'gar');
    await tester.pump(const Duration(milliseconds: 100));

    // Yazım sürerken hiçbir istek atılmamalı.
    expect(jobQueries(api).length, 1);

    // Yazım durunca tek istek çıkıyor.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(jobQueries(api).length, 2);
    expect(jobQueries(api).last['query'], 'gar');
  });

  testWidgets('boş sonuç metni süzgeci ve aramayı ayırıyor', (tester) async {
    final api = _api({0: _pageBody(const [], last: true)});

    await pumpPage(tester, api);
    expect(find.text('Yakınında henüz ilan yok'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'garson');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('ile eşleşen iş bulunamadı'), findsOneWidget);
    expect(find.text('Yakınında henüz ilan yok'), findsNothing);
  });

  testWidgets('süzgeç sheet\'i seçilenleri Uygula ile sunucuya gönderiyor', (
    tester,
  ) async {
    final api = _api({0: _pageBody(const [], last: true)});

    await pumpPage(tester, api);

    await tester.tap(find.text('Süzgeçler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tekrarlı'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saatlik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    final last = jobQueries(api).last;
    expect(last['type'], 'RECURRING');
    expect(last['salaryType'], 'HOURLY');
  });

  testWidgets('Uygula\'ya basılmadan kapanan sheet sorguyu değiştirmiyor', (
    tester,
  ) async {
    final api = _api({0: _pageBody(const [], last: true)});

    await pumpPage(tester, api);
    final before = jobQueries(api).length;

    await tester.tap(find.text('Süzgeçler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tekrarlı'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(jobQueries(api).length, before);
    expect(find.text('Tekrarlı'), findsNothing);
  });

  testWidgets('Temizle bütün alanları sıfırlıyor', (tester) async {
    final api = _api({0: _pageBody(const [], last: true)});

    await pumpPage(tester, api);

    await tester.tap(find.text('Süzgeçler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tekrarlı'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kurumsal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temizle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    final last = jobQueries(api).last;
    expect(last.containsKey('type'), isFalse);
    expect(last.containsKey('employerType'), isFalse);
  });

  testWidgets('sıralama menüsü yalnız sunucunun dört alanını sunuyor', (
    tester,
  ) async {
    final api = _api({0: _pageBody(const [], last: true)});

    await pumpPage(tester, api);

    await tester.tap(find.text('Sırala'));
    await tester.pumpAndSettle();

    for (final option in JobSortOption.values) {
      expect(find.text(option.label), findsOneWidget);
    }
    expect(find.text('En yakın'), findsNothing);

    await tester.tap(find.text('Ücret (azalan)'));
    await tester.pumpAndSettle();

    expect(jobQueries(api).last['sort'], 'salary,desc');
  });

  testWidgets(
    'etkin süzgeç sayısı çubukta görünüyor ve çip tek tek siliniyor',
    (tester) async {
      final api = _api({0: _pageBody(const [], last: true)});

      await pumpPage(tester, api);

      await tester.tap(find.text('Süzgeçler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tekrarlı'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saatlik'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uygula'));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Tekrarlı'), findsOneWidget);

      // Çipin çarpısı yalnız o alanı temizliyor.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      final last = jobQueries(api).last;
      expect(last.containsKey('type'), isFalse);
      expect(last['salaryType'], 'HOURLY');
    },
  );

  testWidgets('konum izni yokken mesafe süzgeci kapalı ve sebebi yazıyor', (
    tester,
  ) async {
    final api = _api({0: _pageBody(const [], last: true)});

    await pumpPage(tester, api);

    await tester.tap(find.text('Süzgeçler'));
    await tester.pumpAndSettle();

    expect(
      find.text('Mesafeye göre süzmek için konum izni gerekiyor.'),
      findsOneWidget,
    );

    // Çipi gerçekten ekrana getirip dokunuyoruz: ekran dışında kalan bir
    // dokunuş kapalı olduğu için değil, ıskaladığı için sonuçsuz kalırdı.
    await tester.ensureVisible(find.text('10 km içinde'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 km içinde'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    // Seçilemedi: çubukta mesafe çipi yok ve sorguda kutu yok.
    expect(find.text('10 km içinde'), findsNothing);
    expect(jobQueries(api).last.containsKey('minLatitude'), isFalse);
  });

  testWidgets('koyu temada da çiziliyor', (tester) async {
    final api = _api({0: _pageBody(_ids(0, 2), last: true)});

    await pumpPage(tester, api, brightness: Brightness.dark);

    expect(find.text('İlan 0-ilan'), findsOneWidget);
  });
}
