import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/providers/map_first_address_controller.dart';
import 'package:koala/product/services/device_location_source.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/widgets/confirmed_address_field.dart';
import 'package:koala/product/widgets/map_first_address_page.dart';

import '../../support/fake_address_search_gateway.dart';
import '../../support/fake_api.dart';
import '../../support/finders.dart';
import '../../support/reference_location_fixtures.dart';

const _debounce = MapFirstAddressController.defaultReverseDebounce;
const _pickerLocation = '/pick-address';
const _originLocation = '/origin';

/// Haritadan gelen ham kamera hedefi: altı ondalıktan uzun, sunucunun
/// olduğu gibi kabul etmeyeceği bir değer.
const _rawPin = LatLng(40.98251234567, 29.02541134567);

/// Testin sürdüğü sayfa ve yardımcıları.
class _Harness {
  _Harness({
    FakeAddressSearchGateway? gateway,
    FakeDeviceLocationSource? location,
    this.initialAddress,
    this.onSave,
  }) : gateway = gateway ?? FakeAddressSearchGateway(),
       location = location ?? FakeDeviceLocationSource() {
    final api = FakeApi(
      handler: (request) =>
          istanbulReferenceResponse(request.path) ??
          const FakeApiResponse(statusCode: 404, body: {'success': false}),
    );
    controller = MapFirstAddressController(
      searchGateway: this.gateway,
      referenceService: ReferenceLocationService.withClient(api.client),
      locationSource: this.location,
      initialAddress: initialAddress,
    );
  }

  final FakeAddressSearchGateway gateway;
  final FakeDeviceLocationSource location;
  final ConfirmedAddress? initialAddress;
  final Future<void> Function(ConfirmedAddress address)? onSave;
  late final MapFirstAddressController controller;

  /// Çağıran ekranın aldığı sonuç; sayfa `pop` ile döndürünce dolar.
  ConfirmedAddress? popped;

  MapFirstAddressPage page() => MapFirstAddressPage(
    controller: controller,
    initialAddress: initialAddress,
    onSave: onSave,
  );

  /// Sayfayı boş bir kök ekranın üstüne `push` ile açar: üretimde de hep
  /// bir formun üstünde duruyor ve kaydedince `pop` ediyor.
  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    final router = GoRouter(
      initialLocation: _originLocation,
      routes: [
        GoRoute(
          path: _originLocation,
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
        GoRoute(
          path: _pickerLocation,
          pageBuilder: (context, state) =>
              MaterialPage<ConfirmedAddress>(key: state.pageKey, child: page()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        routerConfig: router,
      ),
    );
    router.push<ConfirmedAddress>(_pickerLocation).then((value) {
      popped = value;
    });
    await tester.pumpAndSettle();
  }

  /// Sayfayı bir formun içinden `push` ile açar; form dönen adresi
  /// `ConfirmedAddressField` ile gösterir.
  Future<void> pumpFromOrigin(WidgetTester tester) async {
    late GoRouter router;
    router = GoRouter(
      initialLocation: _originLocation,
      routes: [
        GoRoute(
          path: _originLocation,
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: ConfirmedAddressField(
                  value: popped,
                  onTap: () async {
                    final result = await router.push<ConfirmedAddress>(
                      _pickerLocation,
                      extra: popped,
                    );
                    setState(() => popped = result);
                  },
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: _pickerLocation,
          pageBuilder: (context, state) =>
              MaterialPage<ConfirmedAddress>(key: state.pageKey, child: page()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  /// Kullanıcı haritayı kaydırıp bıraktı: harita "hareket" ve "durdu" der,
  /// debounce dolunca ters geokod çağrılır.
  Future<void> dropPin(WidgetTester tester, LatLng target) async {
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    map.onCameraMove!(CameraPosition(target: target));
    map.onCameraIdle!();
    await tester.pump(_debounce);
    await tester.pump();
  }

  /// Ters geokod bekleyen zamanlayıcı testin sonunda kalmasın.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(_debounce);
    await tester.pump();
  }
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('address-save'));
  await tester.ensureVisible(save);
  await tester.pump();
  await tester.tap(save);
  await tester.pump();
  await tester.pump();
}

Future<void> _pickOption(
  WidgetTester tester,
  String fieldLabel,
  String option,
) async {
  await tester.ensureVisible(find.text(fieldLabel));
  await tester.pump();
  await tester.tap(find.text(fieldLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

ConfirmedAddress _initialAddress() => const ConfirmedAddress(
  country: ReferenceLocation(id: 'country-1', name: 'TÜRKİYE'),
  city: ReferenceLocation(id: 'city-1', name: 'İSTANBUL'),
  district: ReferenceLocation(id: 'district-1', name: 'KADIKÖY'),
  components: AddressComponents(
    neighborhood: 'Eski Mahalle',
    thoroughfare: 'Eski Sokak',
    buildingNumber: '1',
    postalCode: '34000',
    floor: '3',
    unitNumber: '7',
  ),
  position: AddressPosition(
    latitude: 40.99,
    longitude: 29.03,
    source: AddressPositionSource.userConfirmedPin,
  ),
);

void main() {
  group('pin → ters geokod', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${brightness.name} temada pin bırakılınca alanlar adaydan dolar ve '
        'düzenlenebilir kalır',
        (tester) async {
          final harness = _Harness(initialAddress: _initialAddress());
          await harness.pump(tester, brightness: brightness);
          expect(harness.gateway.reverseCalls, isEmpty);

          await harness.dropPin(tester, _rawPin);

          expect(harness.gateway.reverseCalls, [_rawPin]);
          expect(harness.controller.neighborhood.text, 'Caferağa Mahallesi');
          expect(harness.controller.thoroughfare.text, 'Moda Caddesi');
          expect(harness.controller.postalCode.text, '34710');
          // Kullanıcıya özel ayrıntılar korunur.
          expect(harness.controller.floor.text, '3');
          expect(harness.controller.unitNumber.text, '7');
          expect(find.text('KADIKÖY'), findsOneWidget);
          expect(find.textContaining('Google Maps önerisi'), findsOneWidget);
          expect(find.text('Sadece pini kullan'), findsOneWidget);

          // Alanlar kilitli değil: kullanıcı bina numarasını düzeltebilir.
          await tester.enterText(_field('Bina No'), '14');
          expect(harness.controller.buildingNumber.text, '14');
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('kaydet, adayın kanıtı ve yuvarlanmış koordinatla döner', (
      tester,
    ) async {
      ConfirmedAddress? saved;
      final harness = _Harness(
        initialAddress: _initialAddress(),
        onSave: (address) async => saved = address,
      );
      await harness.pump(tester);
      await harness.dropPin(tester, _rawPin);

      await _tapSave(tester);

      final body = saved!.toWrite().toJson();
      expect(body['countryId'], 'country-1');
      expect(body['cityId'], 'city-1');
      expect(body['districtId'], 'district-1');
      expect(body['candidateToken'], 'reverse-proof');
      expect(body['position'], {
        'latitude': 40.982512,
        'longitude': 29.025411,
        'source': 'REVERSE_GEOCODE_CONFIRMED',
      });
      expect(body['components'], {
        'neighborhood': 'Caferağa Mahallesi',
        'thoroughfare': 'Moda Caddesi',
        'buildingNumber': '12',
        'postalCode': '34710',
        'floor': '3',
        'unitNumber': '7',
      });
    });

    testWidgets('"Sadece pini kullan" aday metinlerini boşaltır, pin kalır', (
      tester,
    ) async {
      final harness = _Harness(initialAddress: _initialAddress());
      await harness.pump(tester);
      await harness.dropPin(tester, _rawPin);

      await tester.ensureVisible(find.text('Sadece pini kullan'));
      await tester.tap(find.text('Sadece pini kullan'));
      await tester.pump();

      expect(harness.controller.neighborhood.text, isEmpty);
      expect(harness.controller.thoroughfare.text, isEmpty);
      expect(harness.controller.candidateToken, isNull);
      expect(harness.controller.pin, _rawPin);
      expect(find.text('Sadece pini kullan'), findsNothing);
    });
  });

  group('precision', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${brightness.name} temada sokak düzeyinde aday bina numarası ipucu '
        'gösterir, numara yazılınca kalkar',
        (tester) async {
          final harness = _Harness(
            gateway: FakeAddressSearchGateway(
              reversePrecision: AddressCandidatePrecision.street,
            ),
          );
          await harness.pump(tester, brightness: brightness);

          await harness.dropPin(tester, _rawPin);

          expect(
            find.text('Öneri bina düzeyine inemedi; bina numarasını girin.'),
            findsOneWidget,
          );
          expect(harness.controller.buildingNumber.text, isEmpty);

          await tester.enterText(_field('Bina No'), '14');
          await tester.pump();

          expect(
            find.text('Öneri bina düzeyine inemedi; bina numarasını girin.'),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('alan gelmezse ipucu çıkmaz', (tester) async {
      final harness = _Harness();
      await harness.pump(tester);

      await harness.dropPin(tester, _rawPin);

      expect(find.textContaining('bina numarasını girin'), findsNothing);
      expect(harness.controller.buildingNumber.text, '12');
    });
  });

  group('ters geokod düşerse', () {
    for (final status in [400, 502]) {
      testWidgets('$status: şerit çıkar, elle giriş devam eder ve kaydolur', (
        tester,
      ) async {
        ConfirmedAddress? saved;
        final harness = _Harness(
          gateway: FakeAddressSearchGateway(
            reverseFailure: FakeAddressSearchGateway.failure(status),
          ),
          onSave: (address) async => saved = address,
        );
        await harness.pump(tester);

        await harness.dropPin(tester, _rawPin);

        expect(find.text(harness.gateway.reverseFailure!.message), findsOne);
        expect(harness.controller.pin, _rawPin);

        await _pickOption(tester, 'İl *', 'İSTANBUL');
        await _pickOption(tester, 'İlçe *', 'KADIKÖY');
        await tester.enterText(_field('Mahalle *'), 'Caferağa Mahallesi');
        await tester.enterText(_field('Cadde / Sokak *'), 'Moda Caddesi');
        await tester.enterText(_field('Bina No'), '12');
        await tester.enterText(_field('Posta Kodu *'), '34710');
        await _tapSave(tester);

        final body = saved!.toWrite().toJson();
        expect(body['cityId'], 'city-1');
        expect(body['districtId'], 'district-1');
        expect(body.containsKey('candidateToken'), isFalse);
        expect(body['position'], {
          'latitude': 40.982512,
          'longitude': 29.025411,
          'source': 'USER_CONFIRMED_PIN',
        });
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets(
        '${brightness.name} temada hizmet alanı dışı: şerit eylemsiz, '
        'kaydet kapalı ve gerekçesi yanında',
        (tester) async {
          var saves = 0;
          final harness = _Harness(
            gateway: FakeAddressSearchGateway(
              reverseFailure:
                  FakeAddressSearchGateway.outsideServiceAreaFailure(),
            ),
            onSave: (_) async => saves++,
          );
          await harness.pump(tester, brightness: brightness);

          await harness.dropPin(tester, _rawPin);

          expect(
            find.text('Adres İstanbul hizmet alanı içinde olmalıdır.'),
            findsOneWidget,
          );
          expect(find.text('Tekrar dene'), findsNothing);
          expect(find.text('Yenile'), findsNothing);

          final save = find.byKey(const ValueKey('address-save'));
          await tester.ensureVisible(save);
          await tester.pump();
          final button = tester.widget<ElevatedButton>(
            find.descendant(of: save, matching: find.byType(ElevatedButton)),
          );
          expect(button.onPressed, isNull, reason: 'kaydet kapalı');
          expect(
            find.byKey(const ValueKey('address-save-blocked-reason')),
            findsOneWidget,
          );
          expect(
            find.text('Kaydetmek için pini İstanbul içine taşıyın.'),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(RegExp('Adresi kaydet')),
            findsOneWidget,
          );

          await tester.tap(save, warnIfMissed: false);
          await tester.pump();
          expect(saves, 0);
          expect(find.text('İl seçin'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('pin İstanbul içine dönünce kaydet ve gerekçe normale döner', (
      tester,
    ) async {
      final harness = _Harness(
        gateway: FakeAddressSearchGateway(
          reverseFailure: FakeAddressSearchGateway.outsideServiceAreaFailure(),
        ),
      );
      await harness.pump(tester);
      await harness.dropPin(tester, const LatLng(39.925533, 32.866287));
      expect(
        find.byKey(const ValueKey('address-save-blocked-reason')),
        findsOneWidget,
      );

      harness.gateway.reverseFailure = null;
      await harness.dropPin(tester, _rawPin);

      expect(
        find.byKey(const ValueKey('address-save-blocked-reason')),
        findsNothing,
      );
      expect(
        find.text('Adres İstanbul hizmet alanı içinde olmalıdır.'),
        findsNothing,
      );
      final button = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const ValueKey('address-save')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);
      expect(find.textContaining('Google Maps önerisi'), findsOneWidget);
    });

    testWidgets('sonuç yok: sunucu metni ve "Tekrar dene", kaydet açık', (
      tester,
    ) async {
      final harness = _Harness(
        gateway: FakeAddressSearchGateway(
          reverseFailure: FakeAddressSearchGateway.noResultFailure(),
        ),
      );
      await harness.pump(tester);

      await harness.dropPin(tester, _rawPin);

      expect(
        find.text(
          'Bu konum için bir adres bulunamadı. Adresi elle tamamlayın.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.text('Yenile'), findsNothing);
      expect(
        find.byKey(const ValueKey('address-save-blocked-reason')),
        findsNothing,
      );
      final button = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const ValueKey('address-save')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('sağlayıcı düştü: sunucu metni ve "Yenile" yeniden ister', (
      tester,
    ) async {
      final harness = _Harness(
        gateway: FakeAddressSearchGateway(
          reverseFailure: FakeAddressSearchGateway.providerFailure(),
        ),
      );
      await harness.pump(tester);

      await harness.dropPin(tester, _rawPin);

      expect(
        find.text('Adres arama servisine şu anda ulaşılamıyor.'),
        findsOneWidget,
      );
      expect(find.text('Yenile'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsNothing);

      harness.gateway.reverseFailure = null;
      await tester.tap(find.text('Yenile'));
      await tester.pump();
      await tester.pump();

      expect(harness.gateway.reverseCalls, [_rawPin, _rawPin]);
      expect(find.text('Yenile'), findsNothing);
      expect(harness.controller.neighborhood.text, 'Caferağa Mahallesi');
      expect(find.textContaining('Google Maps önerisi'), findsOneWidget);
    });

    testWidgets('sunucu metin göndermediyse Türkçe yedek görünür', (
      tester,
    ) async {
      final harness = _Harness(
        gateway: FakeAddressSearchGateway(
          reverseFailure: FakeAddressSearchGateway.providerFailure(message: ''),
        ),
      );
      await harness.pump(tester);

      await harness.dropPin(tester, _rawPin);

      expect(
        find.text(
          'Adres servisi şu an yanıt vermiyor; birazdan yeniden deneyin.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('eksik alanla kaydet satır içi hata gösterir, ekran kalır', (
      tester,
    ) async {
      var saves = 0;
      final harness = _Harness(
        gateway: FakeAddressSearchGateway(
          reverseFailure: FakeAddressSearchGateway.failure(502),
        ),
        onSave: (_) async => saves++,
      );
      await harness.pump(tester);
      await harness.dropPin(tester, _rawPin);
      expect(find.text('İl seçin'), findsNothing);

      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(saves, 0);
      expect(find.byType(MapFirstAddressPage), findsOneWidget);
      expect(find.text('İl seçin'), findsOneWidget);
      expect(find.text('İlçe seçin'), findsOneWidget);
      expect(find.text('Mahalle zorunlu'), findsOneWidget);
      expect(find.text('Cadde veya sokak zorunlu'), findsOneWidget);
      expect(find.text('Posta kodu 5 haneli olmalı'), findsOneWidget);

      // Kullanıcı düzelttikçe hata satırı kalkar.
      await tester.enterText(_field('Mahalle *'), 'Caferağa Mahallesi');
      await tester.pump();
      expect(find.text('Mahalle zorunlu'), findsNothing);
    });

    testWidgets('kayıt sunucuda düşerse ekran kapanmaz ve hata gösterilir', (
      tester,
    ) async {
      final harness = _Harness(
        initialAddress: _initialAddress(),
        onSave: (_) async => throw const ApiException(
          message: 'Adres kaydedilemedi.',
          type: ApiErrorType.server,
          statusCode: 500,
        ),
      );
      await harness.pump(tester);

      await _tapSave(tester);

      expect(find.byType(MapFirstAddressPage), findsOneWidget);
      expect(find.text('Adres kaydedilemedi.'), findsOneWidget);
    });
  });

  group('arama', () {
    testWidgets('seçilen aday alanları doldurur ve haritayı taşır', (
      tester,
    ) async {
      final harness = _Harness(initialAddress: _initialAddress());
      await harness.pump(tester);

      await tester.enterText(
        _field('Adres ara (mahalle, cadde, bina)'),
        'Moda Caddesi',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(harness.gateway.queries, ['Moda Caddesi']);
      expect(find.text('Moda Caddesi 12'), findsOneWidget);

      await tester.tap(find.text('Moda Caddesi 12'));
      await tester.pump();
      await tester.pump();

      expect(harness.gateway.resolveCalls, 1);
      expect(harness.controller.neighborhood.text, 'Caferağa Mahallesi');
      expect(harness.controller.candidateToken, 'search-proof');
      expect(
        harness.controller.pendingCameraTarget,
        const LatLng(40.987654, 29.031111),
        reason: 'Harita platform görünümü kurulmadığı için hedef bekliyor.',
      );
      expect(harness.controller.pin, const LatLng(40.987654, 29.031111));
      expect(
        find.text('Moda Caddesi 12'),
        findsNothing,
        reason: 'liste kapandı',
      );
      expect(harness.gateway.reverseCalls, isEmpty);
    });
  });

  group('cihaz konumu', () {
    testWidgets('açılışta izin varsa pin cihazda dolar, izin istenmez', (
      tester,
    ) async {
      const device = LatLng(41.04, 29.0);
      final harness = _Harness(
        location: FakeDeviceLocationSource(granted: device),
      );
      await harness.pump(tester);
      await harness.settle(tester);

      expect(harness.location.requestCalls, 0);
      expect(harness.gateway.reverseCalls, [device]);
      expect(harness.controller.pendingCameraTarget, device);
    });

    testWidgets('açılışta izin yoksa şehir merkezi pin olur, izin istenmez', (
      tester,
    ) async {
      final harness = _Harness();
      await harness.pump(tester);
      await harness.settle(tester);

      expect(harness.location.requestCalls, 0);
      expect(harness.location.currentIfGrantedCalls, 1);
      expect(harness.gateway.reverseCalls, hasLength(1));
    });

    testWidgets('"Konumumu kullan" izni o anda ister', (tester) async {
      const device = LatLng(41.04, 29.0);
      final harness = _Harness(
        initialAddress: _initialAddress(),
        location: FakeDeviceLocationSource(
          requestResult: const DeviceLocationResult.located(device),
        ),
      );
      await harness.pump(tester);
      expect(harness.location.requestCalls, 0);

      await tester.tap(findAppIcon(AppIcons.myLocation));
      await tester.pump();
      await harness.settle(tester);

      expect(harness.location.requestCalls, 1);
      expect(harness.controller.pin, device);
      expect(harness.gateway.reverseCalls, [device]);
    });

    testWidgets('izin reddedilirse mesaj çıkar ve pin elle seçilebilir', (
      tester,
    ) async {
      final harness = _Harness(initialAddress: _initialAddress());
      await harness.pump(tester);

      await tester.tap(findAppIcon(AppIcons.myLocation));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Konum izni olmadan da pini elle seçebilirsiniz.'),
        findsOneWidget,
      );
      expect(harness.controller.pin, const LatLng(40.99, 29.03));
    });
  });

  group('çağıran ekran', () {
    testWidgets('kaydet geri döner ve form yeni adresi gösterir', (
      tester,
    ) async {
      final harness = _Harness(initialAddress: _initialAddress());
      await harness.pumpFromOrigin(tester);
      expect(find.text('Haritadan seçin'), findsOneWidget);

      await tester.tap(find.text('Haritadan seçin'));
      await tester.pumpAndSettle();
      expect(find.byType(MapFirstAddressPage), findsOneWidget);

      await harness.dropPin(tester, _rawPin);
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.byType(MapFirstAddressPage), findsNothing);
      expect(harness.popped?.candidateToken, 'reverse-proof');
      expect(
        find.text('Moda Caddesi 12, Caferağa Mahallesi, KADIKÖY/İSTANBUL'),
        findsOneWidget,
      );
      expect(find.text('Haritadan seçin'), findsNothing);
    });
  });
}
