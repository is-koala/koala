import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_filter_selection.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_filter_sheet.dart';
import 'package:koala/product/services/reference_location_service.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

Map<String, dynamic> _list(List<Map<String, String>> rows) => {
  'success': true,
  'data': rows,
};

/// Ülke → il → ilçe zincirini karşılayan sahte sunucu.
FakeApi _referenceApi() {
  return FakeApi(
    handler: (RequestOptions options) {
      final path = options.path;
      if (path.endsWith('/districts')) {
        return FakeApiResponse(
          statusCode: 200,
          body: _list([
            {'id': 'district-1', 'name': 'Çankaya'},
            {'id': 'district-2', 'name': 'Keçiören'},
          ]),
        );
      }
      if (path.endsWith('/cities')) {
        return FakeApiResponse(
          statusCode: 200,
          body: _list([
            {'id': 'city-6', 'name': 'Ankara'},
            {'id': 'city-34', 'name': 'İstanbul'},
          ]),
        );
      }
      return FakeApiResponse(
        statusCode: 200,
        body: _list([
          {'id': 'country-1', 'name': 'Türkiye', 'code': 'TR'},
        ]),
      );
    },
  );
}

/// Sheet'i açan tek butonluk sayfa.
Widget sheetOpener({
  required FakeApi api,
  required ValueChanged<JobFilterSelection?> onApplied,
  JobFilterSelection selection = const JobFilterSelection(),
  bool hasLocation = false,
}) {
  return Builder(
    builder: (context) => TextButton(
      onPressed: () async {
        onApplied(
          await JobFilterSheet.show(
            context,
            selection: selection,
            categories: JobCategorySeeds.all,
            hasLocation: hasLocation,
            locationService: ReferenceLocationService.withClient(api.client),
          ),
        );
      },
      child: const Text('aç'),
    ),
  );
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

/// Sheet uzun; alt bölümler ekrana ancak kaydırılınca giriyor.
Future<void> tapScrolled(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.dark ? 'koyu' : 'açık';

    testWidgets('$themeName temada bütün bölümler hatasız çiziliyor', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        sheetOpener(api: _referenceApi(), onApplied: (_) {}),
        brightness: brightness,
      );
      await openSheet(tester);

      expect(tester.takeException(), isNull);
      for (final section in const [
        'Kategori',
        'Tür',
        'Konum',
        'Ücret tipi',
        'İşveren tipi',
        'Ücret aralığı',
        'Mesafe',
        'Şartlar',
      ]) {
        expect(find.text(section), findsOneWidget, reason: section);
      }
    });
  }

  testWidgets('il seçilmeden ilçe listesi açılmıyor', (tester) async {
    final api = _referenceApi();
    await pumpInApp(tester, sheetOpener(api: api, onApplied: (_) {}));
    await openSheet(tester);

    await tester.tap(find.text('İlçe'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Çankaya'), findsNothing);
  });

  testWidgets('il seçimi ülke zincirinden geçip sorguya id koyuyor', (
    tester,
  ) async {
    final api = _referenceApi();
    JobFilterSelection? applied;

    await pumpInApp(
      tester,
      sheetOpener(api: api, onApplied: (value) => applied = value),
    );
    await openSheet(tester);

    await tester.tap(find.text('İl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ankara'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    expect(
      api.requests.map((request) => request.path),
      containsAllInOrder([
        '/reference/countries',
        '/reference/countries/country-1/cities',
      ]),
    );
    expect(applied?.city?.id, 'city-6');
    expect(applied?.toQuery().toQueryParameters()['cityId'], 'city-6');
  });

  testWidgets('il değişince ilçe seçimi sıfırlanıyor', (tester) async {
    final api = _referenceApi();
    JobFilterSelection? applied;

    await pumpInApp(
      tester,
      sheetOpener(api: api, onApplied: (value) => applied = value),
    );
    await openSheet(tester);

    await tester.tap(find.text('İl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ankara'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlçe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çankaya'));
    await tester.pumpAndSettle();

    // İkinci kez il seçilince ilçe düşmeli.
    await tester.tap(find.text('İl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İstanbul'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    expect(applied?.city?.id, 'city-34');
    expect(applied?.district, isNull);
  });

  testWidgets('sigorta anahtarı kapalıyken alan sorguya konmuyor', (
    tester,
  ) async {
    JobFilterSelection? applied;

    await pumpInApp(
      tester,
      sheetOpener(api: _referenceApi(), onApplied: (value) => applied = value),
    );
    await openSheet(tester);

    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    expect(
      applied?.toQuery().toQueryParameters().containsKey('insuranceRequired'),
      isFalse,
    );
  });

  testWidgets('sigorta anahtarı açıkken true gidiyor', (tester) async {
    JobFilterSelection? applied;

    await pumpInApp(
      tester,
      sheetOpener(api: _referenceApi(), onApplied: (value) => applied = value),
    );
    await openSheet(tester);

    await tapScrolled(tester, find.text('Sigortalı ilanlar'));
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    expect(applied?.toQuery().toQueryParameters()['insuranceRequired'], isTrue);
  });

  testWidgets('anahtar açılıp kapatılınca alan yine sorguya konmuyor', (
    tester,
  ) async {
    JobFilterSelection? applied;

    await pumpInApp(
      tester,
      sheetOpener(api: _referenceApi(), onApplied: (value) => applied = value),
    );
    await openSheet(tester);

    // Kapalı anahtar "sigortasız ilanları getir" demek değil; alan sorguya
    // hiç konmamalı.
    await tapScrolled(tester, find.text('Sigortalı ilanlar'));
    await tapScrolled(tester, find.text('Sigortalı ilanlar'));
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    expect(
      applied?.toQuery().toQueryParameters().containsKey('insuranceRequired'),
      isFalse,
    );
  });

  testWidgets('ücret alanları minSalary/maxSalary olarak gidiyor', (
    tester,
  ) async {
    JobFilterSelection? applied;

    await pumpInApp(
      tester,
      sheetOpener(api: _referenceApi(), onApplied: (value) => applied = value),
    );
    await openSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'En az ₺'), '750');
    await tester.enterText(find.widgetWithText(TextField, 'En çok ₺'), '3000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    final query = applied!.toQuery().toQueryParameters();
    expect(query['minSalary'], 750.0);
    expect(query['maxSalary'], 3000.0);
  });

  testWidgets('konum varken mesafe seçilebiliyor ve kutuya çevriliyor', (
    tester,
  ) async {
    JobFilterSelection? applied;

    await pumpInApp(
      tester,
      sheetOpener(
        api: _referenceApi(),
        onApplied: (value) => applied = value,
        hasLocation: true,
      ),
    );
    await openSheet(tester);

    expect(
      find.text('Mesafeye göre süzmek için konum izni gerekiyor.'),
      findsNothing,
    );

    await tapScrolled(tester, find.text('10 km içinde'));
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    expect(applied?.radiusKm, 10);
    expect(
      applied!
          .toQuery(latitude: 39.92, longitude: 32.85)
          .toQueryParameters()
          .containsKey('minLatitude'),
      isTrue,
    );
  });

  testWidgets('vazgeçilince null dönüyor, seçim uygulanmıyor', (tester) async {
    var called = false;
    JobFilterSelection? applied;

    await pumpInApp(
      tester,
      sheetOpener(
        api: _referenceApi(),
        onApplied: (value) {
          called = true;
          applied = value;
        },
      ),
    );
    await openSheet(tester);

    await tester.tap(find.text('Tekrarlı'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(applied, isNull);
  });
}
