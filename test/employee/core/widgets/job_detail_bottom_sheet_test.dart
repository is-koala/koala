import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/core/widgets/employer_type_badge.dart';
import 'package:koala/employee/core/widgets/job_detail_bottom_sheet.dart';
import 'package:koala/employee/core/widgets/job_location_card.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/saved_jobs_provider.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';
import 'package:koala/employee/features/jobs/services/saved_jobs_service.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/services/job_gallery_service.dart';
import 'package:provider/provider.dart';

import '../../../support/fake_api.dart';
import '../../../support/fixtures.dart';
import '../../../support/pump.dart';

/// `APPROXIMATE` yanıtta sunucunun bıraktığı metin: sokak, bina ve daire
/// silinmiş, ilçe/il kalmış.
const _maskedLabel = 'Caferağa, Kadıköy';

/// `EXACT` yanıtta gelen açık adres.
const _exactLabel = 'Caferağa Mah. Moda Cad. No:12 D:4, Kadıköy';

Map<String, dynamic> _detailBody({
  required String precision,
  required String displayAddress,
  String? createdAt,
  int? headcount,
  int hiredCount = 0,
}) => {
  'success': true,
  'data': {
    'id': 'job_ayni',
    'title': 'Part-time Garson',
    'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
    'type': 'ONE_TIME',
    'salaryType': 'DAILY',
    'salary': 800,
    'status': 'OPEN',
    'createdAt': ?createdAt,
    'headcount': ?headcount,
    'hiredCount': hiredCount,
    'addressPrecision': precision,
    'address': {
      'id': 'adr-1',
      'countryId': 'c-1',
      'countryName': 'Türkiye',
      'countryCode': 'TR',
      'cityId': 'ct-1',
      'cityName': 'İstanbul',
      'districtId': 'd-1',
      'districtName': 'Kadıköy',
      'displayAddress': displayAddress,
    },
  },
};

/// Detay ucunu verilen gövdeyle, diğer her şeyi boşla karşılayan sahte sunucu.
FakeApi _api(Map<String, dynamic> detail) {
  return FakeApi(
    handler: (RequestOptions options) {
      if (options.path.contains('/images')) {
        return const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        );
      }
      return FakeApiResponse(statusCode: 200, body: detail);
    },
  );
}

/// Sheet'i **açık** hâlde çizer.
///
/// Konum kartı yalnız sheet genişleyince çiziliyor (`expandProgress`), ve o
/// oran `DraggableScrollableController`'dan geliyor — o yüzden kart, üretimde
/// olduğu gibi gerçek bir `DraggableScrollableSheet` içinde açılıyor. Kapalı
/// sheet'i kandırıp kartı zorla çizmek, kartın hiç görünmediği bir kusuru
/// yeşile boyardı.
Future<void> _pumpOpenSheet(
  WidgetTester tester, {
  required Job job,
  required FakeApi api,
  Brightness brightness = Brightness.light,
}) async {
  final sheetController = DraggableScrollableController();
  addTearDown(sheetController.dispose);

  await pumpInApp(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SavedJobsProvider(
            service: SavedJobsService.withClient(api.client),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ApplyProvider(
            service: JobApplicationService.withClient(api.client),
          ),
        ),
      ],
      child: DraggableScrollableSheet(
        controller: sheetController,
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => JobDetailBottomSheet(
          job: job,
          scrollController: scrollController,
          sheetController: sheetController,
          jobService: JobService.withClient(api.client),
          galleryService: JobGalleryService.withClient(api.client),
        ),
      ),
    ),
    brightness: brightness,
  );
  await tester.pumpAndSettle();

  sheetController.jumpTo(0.95);
  await tester.pumpAndSettle();

  // Gövde tembel bir `ListView`: konum kartı listenin altında, kaydırılana
  // kadar ağaçta hiç yok. `find` onu bulamazsa iddia "kart yanlış" değil
  // "kart yok" derdi.
  await tester.scrollUntilVisible(
    find.byType(JobLocationCard),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Finder _inCard(Finder matching) =>
    find.descendant(of: find.byType(JobLocationCard), matching: matching);

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.dark ? 'koyu' : 'açık';

    group('İlan detayı konum satırı ($themeName tema)', () {
      testWidgets('sunucu kesin verdiyse açık adres "Konum" diye yazıyor', (
        tester,
      ) async {
        await _pumpOpenSheet(
          tester,
          job: buildJob(
            id: 'job_ayni',
            addressPrecision: AddressPrecision.exact,
          ),
          api: _api(
            _detailBody(precision: 'EXACT', displayAddress: _exactLabel),
          ),
          brightness: brightness,
        );

        expect(_inCard(find.text('Konum')), findsOneWidget);
        expect(_inCard(find.text('Yaklaşık konum')), findsNothing);
        expect(_inCard(find.text(_exactLabel)), findsOneWidget);
      });

      testWidgets('sunucu yaklaşık verdiyse satır "Yaklaşık konum" oluyor', (
        tester,
      ) async {
        // Sunucu bu yanıtta sokağı, binayı ve daireyi zaten silmiş; sızıntı
        // yok. Ama kalanı "Konum" diye sunmak adresin bundan ibaret olduğunu
        // ima ederdi — is-koala/koala#93'ün dördüncü maddesi bu.
        await _pumpOpenSheet(
          tester,
          job: buildJob(id: 'job_ayni'),
          api: _api(
            _detailBody(precision: 'APPROXIMATE', displayAddress: _maskedLabel),
          ),
          brightness: brightness,
        );

        expect(_inCard(find.text('Yaklaşık konum')), findsOneWidget);
        expect(_inCard(find.text('Konum')), findsNothing);
        expect(
          _inCard(find.textContaining('atama kurulduğunda')),
          findsOneWidget,
        );
      });

      testWidgets('kesinliği özet değil, gelen detay belirliyor', (
        tester,
      ) async {
        // Özet `EXACT` diyor, detay `APPROXIMATE`. Kural istemcide yeniden
        // kurulmuyor: en son sunucu ne dediyse o geçerli. Bayrağı sabitleyen
        // ya da özete kilitleyen bir uygulama burada düşer.
        await _pumpOpenSheet(
          tester,
          job: buildJob(
            id: 'job_ayni',
            addressPrecision: AddressPrecision.exact,
          ),
          api: _api(
            _detailBody(precision: 'APPROXIMATE', displayAddress: _maskedLabel),
          ),
          brightness: brightness,
        );

        expect(_inCard(find.text('Yaklaşık konum')), findsOneWidget);
        expect(_inCard(find.text('Konum')), findsNothing);
      });
    });
  }

  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.dark ? 'koyu' : 'açık';

    group('İlan detayı işveren türü ve sayılar ($themeName tema)', () {
      testWidgets('işveren türü rozeti, yayın tarihi ve aranan kişi yazılır', (
        tester,
      ) async {
        await _pumpOpenSheet(
          tester,
          job: buildJob(
            id: 'job_ayni',
            employerType: JobEmployerType.individual,
            sector: 'Yiyecek-İçecek',
          ),
          api: _api(
            _detailBody(
              precision: 'APPROXIMATE',
              displayAddress: _maskedLabel,
              createdAt: '2026-09-01T10:00:00Z',
              headcount: 3,
              hiredCount: 1,
            ),
          ),
          brightness: brightness,
        );

        // Harness sheet'i konum kartına kadar kaydırıyor; rozet en üstteki
        // şirket satırında ve tembel listede yeniden yukarı çıkmadan yok.
        final scrollable = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.byType(EmployerTypeBadge),
          -300,
          scrollable: scrollable,
        );
        expect(
          tester.widget<EmployerTypeBadge>(find.byType(EmployerTypeBadge)).type,
          JobEmployerType.individual,
        );
        await tester.scrollUntilVisible(
          find.text('Yayın tarihi'),
          300,
          scrollable: scrollable,
        );
        expect(find.text('Yayın tarihi'), findsOneWidget);
        expect(
          find.text(DateTime.utc(2026, 9, 1, 10).toLocal().asShortDate),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Aranan kişi'),
          300,
          scrollable: scrollable,
        );
        expect(find.text('1 / 3 alındı'), findsOneWidget);
      });

      // Eski sunucu ne yayın tarihi ne kişi sayısı gönderiyor; satırlar yok.
      testWidgets('alanlar gelmezse satırlar çizilmez', (tester) async {
        await _pumpOpenSheet(
          tester,
          job: buildJob(id: 'job_ayni'),
          api: _api(
            _detailBody(precision: 'APPROXIMATE', displayAddress: _maskedLabel),
          ),
          brightness: brightness,
        );

        expect(find.text('Yayın tarihi'), findsNothing);
        expect(find.text('Aranan kişi'), findsNothing);
      });
    });
  }
}
