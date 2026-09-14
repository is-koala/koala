import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/pages/b_create_page.dart';
import 'package:koala/business/features/home/services/b_payment_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';

/// İlan formu adresi haritada seçtirir: alan `/pick-address`'i
/// `push<ConfirmedAddress>` ile açar, dönen adres özet olarak görünür ve
/// yeniden açılışta `extra` olarak geri verilir. Harita ekranının kendisi
/// `test/product/widgets/map_first_address_page_test.dart`'ta.
const _createLocation = '/business/create';
const _pickerLocation = '/pick-address';

const _pickedAddress = ConfirmedAddress(
  country: ReferenceLocation(id: 'country-1', name: 'TÜRKİYE'),
  city: ReferenceLocation(id: 'city-1', name: 'İSTANBUL'),
  district: ReferenceLocation(id: 'district-1', name: 'KADIKÖY'),
  components: AddressComponents(
    neighborhood: 'Caferağa Mahallesi',
    thoroughfare: 'Moda Caddesi',
    buildingNumber: '12',
    postalCode: '34710',
  ),
  position: AddressPosition(
    latitude: 40.982512,
    longitude: 29.025411,
    source: AddressPositionSource.userConfirmedPin,
  ),
);

/// Harita ekranının yerine geçen rota; açılırken aldığı `extra`'yı kaydeder
/// ve [_pickedAddress] ile kapanır.
class _PickerStub extends StatefulWidget {
  const _PickerStub({required this.extra, required this.onOpened});

  final Object? extra;
  final ValueChanged<Object?> onOpened;

  @override
  State<_PickerStub> createState() => _PickerStubState();
}

class _PickerStubState extends State<_PickerStub> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onOpened(widget.extra);
      if (mounted) context.pop(_pickedAddress);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}

Future<List<Object?>> _pumpCreate(
  WidgetTester tester, {
  ConfirmedAddress? initialAddress,
}) async {
  final userApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'id': 'employer-1',
          'firstName': 'Ayşe',
          'lastName': 'İşveren',
          'email': 'ayse@example.com',
          'isEmployer': true,
          'identityVerified': true,
        },
      },
    ),
  );
  final userProvider = UserProvider(
    userService: UserService.withClient(userApi.client),
  );
  await tester.runAsync(userProvider.load);
  final emptyApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {'success': true, 'data': []},
    ),
  );

  final openedWith = <Object?>[];
  final router = GoRouter(
    initialLocation: _createLocation,
    routes: [
      GoRoute(
        path: _createLocation,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: BCreatePage(
            paymentService: BPaymentService.withClient(emptyApi.client),
            initialAddress: initialAddress,
          ),
        ),
      ),
      GoRoute(
        path: _pickerLocation,
        pageBuilder: (context, state) => MaterialPage<ConfirmedAddress>(
          key: state.pageKey,
          child: _PickerStub(extra: state.extra, onOpened: openedWith.add),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider(
          create: (_) => JobCategoryProvider(
            service: JobCategoryService.withClient(emptyApi.client),
          ),
        ),
      ],
      child: MaterialApp.router(theme: lightTheme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return openedWith;
}

Future<void> _openPicker(WidgetTester tester, Finder field) async {
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('konum alanı harita ekranını açar ve dönen adresi gösterir', (
    tester,
  ) async {
    final openedWith = await _pumpCreate(tester);
    expect(find.text('Haritadan seçin'), findsOneWidget);

    await _openPicker(tester, find.text('Haritadan seçin'));

    expect(openedWith, [null]);
    expect(find.byType(BCreatePage), findsOneWidget);
    expect(find.text('Haritadan seçin'), findsNothing);
    expect(
      find.text('Moda Caddesi 12, Caferağa Mahallesi, KADIKÖY/İSTANBUL'),
      findsOneWidget,
    );
  });

  testWidgets('seçili adres yeniden açılışta haritaya ön dolum olarak gider', (
    tester,
  ) async {
    final openedWith = await _pumpCreate(
      tester,
      initialAddress: _pickedAddress,
    );
    final summary = find.text(
      'Moda Caddesi 12, Caferağa Mahallesi, KADIKÖY/İSTANBUL',
    );
    expect(summary, findsOneWidget);

    await _openPicker(tester, summary);

    expect(openedWith, [_pickedAddress]);
  });
}
