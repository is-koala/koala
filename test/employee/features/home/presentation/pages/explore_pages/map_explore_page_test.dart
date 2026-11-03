import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';
import 'package:koala/employee/features/home/presentation/pages/explore_pages/map_explore_page.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/presentation/providers/map_explore_controller.dart';
import 'package:koala/employee/features/home/presentation/providers/page_provider.dart';
import 'package:koala/employee/features/home/presentation/providers/search_provider.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_marker_generator.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/product/constants/app_map_style.dart';
import 'package:provider/provider.dart';

import '../../../../../../support/fake_api.dart';
import '../../../../../../support/fake_maps_availability.dart';
import '../../../../../../support/fixtures.dart';
import '../../../../../../support/pump.dart';

/// Sunucunun bir ilanı hangi kesinlikte verdiği; yükün tamamı bu iki alanla
/// değişiyor. `JobMapper` koordinatı **daima** yazıyor, yalnız değeri yuvarlıyor
/// — yani bayrağı okumayan bir istemci farkı hiç göremez.
Map<String, dynamic> _jobBody({
  required double latitude,
  required double longitude,
  required String precision,
}) => {
  'id': 'job_ayni',
  'title': 'Part-time Garson',
  'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
  'type': 'ONE_TIME',
  'salaryType': 'DAILY',
  'salary': 800,
  'status': 'OPEN',
  'cityName': 'İstanbul',
  'districtName': 'Kadıköy',
  'latitude': latitude,
  'longitude': longitude,
  'addressPrecision': precision,
};

Map<String, dynamic> _page(Map<String, dynamic> job) => {
  'success': true,
  'data': {
    'content': [job],
    'page': 0,
    'size': 100,
    'totalElements': 1,
    'totalPages': 1,
    'first': true,
    'last': true,
  },
};

/// Aynı ilanı sırayla veren sahte sunucu: ilk çağrıda yetkili görünüm, sonraki
/// çağrılarda yetkisiz görünüm. Gerçek hayatta aradan geçen olay atamanın
/// bitmesi ya da iptal edilmesi.
bool _isJobCategories(RequestOptions options) =>
    options.path.contains('job-categories');

FakeApiResponse _emptyCategories() =>
    const FakeApiResponse(statusCode: 200, body: {'success': true, 'data': []});

/// İlan isteklerini kategori ucundan ayırır: Süzgeçler sheet'i kategoriyi
/// yüklemese bile FakeApi'nin iş sırasını bozmasın.
List<Map<String, dynamic>> _jobQueries(FakeApi api) => [
  for (final request in api.requests)
    if (!request.path.contains('job-categories')) request.queryParameters,
];

FakeApi _apiServing(List<Map<String, dynamic>> jobsInOrder) {
  var call = 0;
  return FakeApi(
    handler: (RequestOptions options) {
      if (_isJobCategories(options)) return _emptyCategories();
      final job = jobsInOrder[call.clamp(0, jobsInOrder.length - 1)];
      call++;
      return FakeApiResponse(statusCode: 200, body: _page(job));
    },
  );
}

const _bounds = JobMapBounds(
  minLatitude: 40.9,
  maxLatitude: 41.1,
  minLongitude: 28.8,
  maxLongitude: 29.1,
);

/// `LocationService` cihazın izin akışını açıyor ve testte o kanalların
/// arkasında kimse yok.
///
/// İki sebeple yanıtlanıyorlar. Cevapsız bırakmak `MissingPluginException`'ı
/// yakalanmamış bir asenkron hataya çeviriyor; ve izin gelmezse sayfa
/// "Harita Yükleniyor..." dönenini sonsuza kadar çeviriyor, `pumpAndSettle` de
/// hiç durmuyor. Konumun kendisi bu testlerin konusu değil — pinlerin
/// kesinliği kullanıcının nerede durduğuna bağlı değil.
void _grantLocationPermission() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/permissions/methods'),
    (call) async => switch (call.method) {
      // PermissionStatus.granted
      'checkPermissionStatus' => 1,
      'requestPermissions' => {
        for (final value in call.arguments as List) value: 1,
      },
      _ => null,
    },
  );

  messenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/geolocator'),
    (call) async => switch (call.method) {
      // LocationAccuracyStatus.precise — "reduced" olsaydı sayfa izin
      // uyarısını açar, testin konusu olmayan bir dialog çizerdi.
      'getLocationAccuracy' => 1,
      'getCurrentPosition' => {'latitude': 41.0, 'longitude': 29.0},
      _ => null,
    },
  );
}

/// Pin görselini bir kez gerçek olay döngüsünde üretir.
///
/// `JobMarkerGenerator` pini SVG'den çiziyor: varlık okuma ve PNG kodlama,
/// ikisi de testin sahte saatiyle değil gerçek olay döngüsüyle ilerliyor, yani
/// `pumpAndSettle` onları beklemiyor. Bir kez `runAsync` içinde ısıtılınca
/// görsel üreticinin statik önbelleğine giriyor ve sayfanın kendi üretimi
/// mikrogörevde bitiyor — testin beklemesi gereken duvar saati kalmıyor, yani
/// makine yükü altında da aynı sonucu veriyor.
Future<void> _warmMarkerArtwork(WidgetTester tester) async {
  await tester.runAsync(
    () => JobMarkerGenerator.markerFor(maskedView(), (_) {}),
  );
}

Future<void> _pumpMap(
  WidgetTester tester,
  MapExploreController controller, {
  bool mapsAvailable = true,
  PageProvider? pageProvider,
  Brightness brightness = Brightness.light,
}) async {
  await _warmMarkerArtwork(tester);
  await pumpInApp(
    tester,
    withMapsAvailability(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SearchProvider()),
          ChangeNotifierProvider.value(value: pageProvider ?? PageProvider()),
          ChangeNotifierProvider(
            create: (_) => JobCategoryProvider(
              service: JobCategoryService.withClient(
                FakeApi(handler: (_) => _emptyCategories()).client,
              ),
            ),
          ),
        ],
        child: MapExplorePage(controller: controller),
      ),
      available: mapsAvailable,
    ),
    brightness: brightness,
  );
}

GoogleMap _map(WidgetTester tester) =>
    tester.widget<GoogleMap>(find.byType(GoogleMap));

void main() {
  setUp(_grantLocationPermission);

  testWidgets('yetki sona erince haritadaki kesin pin yerini bırakıyor', (
    tester,
  ) async {
    // Kabul maddesi: "önbellekte kalmış tam adres yetki sona erdikten sonra
    // gösterilmez" (is-koala/koala#10). Sayfanın önbelleği ilan kimliğine
    // bakarsa aynı id ikinci kez geldiğinde eski **kesin** pin ekranda kalır
    // ve iş hâlâ tam adresinde duruyormuş gibi görünür — testin tuttuğu şey
    // bu, `cacheKeyFor`'un metni değil.
    final api = _apiServing([
      _jobBody(
        latitude: exactLatitude,
        longitude: exactLongitude,
        precision: 'EXACT',
      ),
      _jobBody(
        latitude: roundedLatitude,
        longitude: roundedLongitude,
        precision: 'APPROXIMATE',
      ),
    ]);
    final controller = MapExploreController(
      service: JobService.withClient(api.client),
      debounce: Duration.zero,
    );

    await _pumpMap(tester, controller);

    controller.onCameraIdle(_bounds);
    await tester.pumpAndSettle();

    expect(_map(tester).markers, hasLength(1));
    expect(
      _map(tester).markers.single.position,
      const LatLng(exactLatitude, exactLongitude),
    );
    expect(_map(tester).circles, isEmpty);

    // Aynı kamera, aynı ilan — yalnız yetki bitti.
    controller.retry();
    await tester.pumpAndSettle();

    expect(_map(tester).markers, hasLength(1));
    expect(
      _map(tester).markers.single.position,
      const LatLng(roundedLatitude, roundedLongitude),
    );
    expect(
      _map(tester).markers.single.position,
      isNot(const LatLng(exactLatitude, exactLongitude)),
    );
  });

  testWidgets('yetki sona erince pin ucundan değil ortasından bağlanıyor', (
    tester,
  ) async {
    final api = _apiServing([
      _jobBody(
        latitude: exactLatitude,
        longitude: exactLongitude,
        precision: 'EXACT',
      ),
      _jobBody(
        latitude: exactLatitude,
        longitude: exactLongitude,
        precision: 'APPROXIMATE',
      ),
    ]);
    final controller = MapExploreController(
      service: JobService.withClient(api.client),
      debounce: Duration.zero,
    );

    await _pumpMap(tester, controller);

    controller.onCameraIdle(_bounds);
    await tester.pumpAndSettle();
    expect(_map(tester).markers.single.anchor, const Offset(0.5, 1.0));

    // Koordinat bilerek aynı bırakıldı: sunucu yuvarlamayı yapmasa bile
    // bayrak tek başına pini yeniden ürettirmeli.
    controller.retry();
    await tester.pumpAndSettle();

    expect(_map(tester).markers.single.anchor, const Offset(0.5, 0.5));
  });

  testWidgets('yaklaşık ilan haritaya belirsizlik dairesiyle çiziliyor', (
    tester,
  ) async {
    final api = _apiServing([
      _jobBody(
        latitude: roundedLatitude,
        longitude: roundedLongitude,
        precision: 'APPROXIMATE',
      ),
    ]);
    final controller = MapExploreController(
      service: JobService.withClient(api.client),
      debounce: Duration.zero,
    );

    await _pumpMap(tester, controller);

    controller.onCameraIdle(_bounds);
    await tester.pumpAndSettle();

    expect(_map(tester).circles, hasLength(1));
    expect(_map(tester).circles.single.radius, greaterThan(0));
  });

  testWidgets('görünen alandan çıkan ilanın pini haritadan düşüyor', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (RequestOptions options) {
        final withinView = options.queryParameters['minLatitude'] == 40.9;
        return FakeApiResponse(
          statusCode: 200,
          body: withinView
              ? _page(
                  _jobBody(
                    latitude: roundedLatitude,
                    longitude: roundedLongitude,
                    precision: 'APPROXIMATE',
                  ),
                )
              : {
                  'success': true,
                  'data': {
                    'content': <Map<String, dynamic>>[],
                    'page': 0,
                    'size': 100,
                    'totalElements': 0,
                    'totalPages': 1,
                    'first': true,
                    'last': true,
                  },
                },
        );
      },
    );
    final controller = MapExploreController(
      service: JobService.withClient(api.client),
      debounce: Duration.zero,
    );

    await _pumpMap(tester, controller);

    controller.onCameraIdle(_bounds);
    await tester.pumpAndSettle();
    expect(_map(tester).markers, hasLength(1));

    controller.onCameraIdle(
      const JobMapBounds(
        minLatitude: 36.0,
        maxLatitude: 36.2,
        minLongitude: 32.0,
        maxLongitude: 32.2,
      ),
    );
    await tester.pumpAndSettle();

    expect(_map(tester).markers, isEmpty);
    expect(_map(tester).circles, isEmpty);
  });

  testWidgets('başlangıç günü çipleri haritanın üstüne binmiyor', (
    tester,
  ) async {
    final api = _apiServing([
      _jobBody(
        latitude: exactLatitude,
        longitude: exactLongitude,
        precision: 'EXACT',
      ),
    ]);
    final controller = MapExploreController(
      service: JobService.withClient(api.client),
      debounce: Duration.zero,
    );

    await _pumpMap(tester, controller);

    expect(find.text('Bugün'), findsNothing);
    expect(find.text('Yarın'), findsNothing);
    expect(find.text('Hafta sonu'), findsNothing);
    expect(find.byTooltip('Süzgeçler'), findsOneWidget);
  });

  testWidgets(
    'Süzgeçler Bugün çipi startFrom/startTo Instant penceresini gönderiyor',
    (tester) async {
      final api = _apiServing([
        _jobBody(
          latitude: exactLatitude,
          longitude: exactLongitude,
          precision: 'EXACT',
        ),
      ]);
      final controller = MapExploreController(
        service: JobService.withClient(api.client),
        debounce: Duration.zero,
      );

      await _pumpMap(tester, controller);
      controller.onCameraIdle(_bounds);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Süzgeçler'));
      await tester.pumpAndSettle();

      expect(find.text('Başlangıç günü'), findsOneWidget);
      expect(find.text('Bugün'), findsOneWidget);
      expect(find.text('Yarın'), findsOneWidget);
      expect(find.text('Hafta sonu'), findsOneWidget);

      await tester.tap(find.text('Bugün'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Uygula'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uygula'));
      await tester.pumpAndSettle();

      final last = _jobQueries(api).last;
      expect(last['startFrom'], isA<String>());
      expect(last['startTo'], isA<String>());
      expect((last['startFrom'] as String).endsWith('Z'), isTrue);
      expect((last['startTo'] as String).endsWith('Z'), isTrue);
    },
  );

  group('harita bayrağı', () {
    // is-koala/koala#172: iOS'ta anahtar boşken ilk `GoogleMap` uygulamayı
    // çökertiyordu. Bayrak kapalıysa harita hiç kurulmaz; kullanıcı yer
    // tutucuyu görür ve listeye geçebilir.
    for (final brightness in Brightness.values) {
      testWidgets('kapalıyken ${brightness.name} temada yer tutucu çizer', (
        tester,
      ) async {
        final api = _apiServing([
          _jobBody(
            latitude: exactLatitude,
            longitude: exactLongitude,
            precision: 'EXACT',
          ),
        ]);
        final controller = MapExploreController(
          service: JobService.withClient(api.client),
          debounce: Duration.zero,
        );

        await _pumpMap(
          tester,
          controller,
          mapsAvailable: false,
          brightness: brightness,
        );
        await tester.pumpAndSettle();

        expect(find.byType(GoogleMap), findsNothing);
        expect(find.byKey(const ValueKey('map-unavailable')), findsOneWidget);
        expect(find.text('Harita bu derlemede kullanılamıyor'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('kapalıyken "Listeye geç" keşfi listeye alır', (tester) async {
      final api = _apiServing([
        _jobBody(
          latitude: exactLatitude,
          longitude: exactLongitude,
          precision: 'EXACT',
        ),
      ]);
      final controller = MapExploreController(
        service: JobService.withClient(api.client),
        debounce: Duration.zero,
      );
      final pageProvider = PageProvider();

      await _pumpMap(
        tester,
        controller,
        mapsAvailable: false,
        pageProvider: pageProvider,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Listeye geç'));
      await tester.pump();

      expect(pageProvider.exploreViewType, ExploreViewType.list);
    });

    testWidgets('açıkken harita eskisi gibi kurulur', (tester) async {
      final api = _apiServing([
        _jobBody(
          latitude: exactLatitude,
          longitude: exactLongitude,
          precision: 'EXACT',
        ),
      ]);
      final controller = MapExploreController(
        service: JobService.withClient(api.client),
        debounce: Duration.zero,
      );

      await _pumpMap(tester, controller);

      expect(find.byType(GoogleMap), findsOneWidget);
      expect(find.byKey(const ValueKey('map-unavailable')), findsNothing);
    });
  });

  group('harita stili', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} temada Koala stilini kullanır, '
          'Haritalar araç çubuğu kapalıdır', (tester) async {
        final controller = MapExploreController(
          service: JobService.withClient(
            _apiServing([
              _jobBody(
                latitude: exactLatitude,
                longitude: exactLongitude,
                precision: 'EXACT',
              ),
            ]).client,
          ),
          debounce: Duration.zero,
        );

        await _pumpMap(tester, controller, brightness: brightness);

        final map = _map(tester);
        expect(
          map.style,
          brightness == Brightness.dark ? AppMapStyle.dark : AppMapStyle.light,
        );
        expect(map.mapToolbarEnabled, isFalse);
      });
    }
  });
}
