import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/pages/b_profile_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/features/account/account_routes.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';

/// Bireysel işveren: şirketi yok, adresi de yok.
Map<String, dynamic> _me({Map<String, dynamic>? address}) => {
  'success': true,
  'data': {
    'id': 'employer-1',
    'firstName': 'Ayşe',
    'lastName': 'İşveren',
    'email': 'ayse@ornek.com',
    'isEmployer': true,
    'identityVerified': true,
    'companies': const [],
    'address': ?address,
  },
};

const _address = {
  'id': 'address-1',
  'countryName': 'TÜRKİYE',
  'cityName': 'İSTANBUL',
  'districtName': 'KADIKÖY',
  'displayAddress': 'Moda Caddesi 12, Caferağa Mahallesi',
  'position': {'latitude': 40.98, 'longitude': 29.02},
};

void main() {
  Future<void> pumpProfile(
    WidgetTester tester, {
    Map<String, dynamic>? address,
    required List<Object?> opened,
  }) async {
    final api = FakeApi(
      handler: (RequestOptions request) {
        if (request.path == '/users/me') {
          return FakeApiResponse(statusCode: 200, body: _me(address: address));
        }
        // İstatistikler: bölüm çizilsin ama bu testin konusu değil.
        return const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'userId': 'employer-1',
              'jobsPosted': 0,
              'completedJobs': 0,
              'averageRating': 0,
              'reviewCount': 0,
            },
          },
        );
      },
    );

    final router = GoRouter(
      initialLocation: '/business/profile',
      routes: [
        GoRoute(
          path: '/business/profile',
          pageBuilder: (context, state) =>
              const MaterialPage<void>(child: BProfilePage()),
        ),
        GoRoute(
          path: AccountRoutes.address,
          pageBuilder: (context, state) {
            opened.add(state.extra);
            return const MaterialPage<void>(
              child: Scaffold(body: Text('adres sahnesi')),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) =>
                UserProvider(userService: UserService.withClient(api.client)),
          ),
          ChangeNotifierProvider(
            create: (_) => BCompanyProvider(
              service: BCompanyService.withClient(api.client),
              companyService: CompanyService.withClient(api.client),
            ),
          ),
        ],
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Ödeme bu adres olmadan başlamıyor; işveren bunu ödeme anında değil
  // profilinde görmeli ve tek dokunuşla adres ekranına gidebilmeli.
  testWidgets(
    'adresi olmayan bireysel işveren profilden adres ekranına gider',
    (tester) async {
      final opened = <Object?>[];
      await pumpProfile(tester, opened: opened);

      final notice = find.byKey(const ValueKey('profile-missing-address'));
      await tester.ensureVisible(notice);
      expect(notice, findsOneWidget);
      expect(find.textContaining('Adresiniz henüz eklenmedi'), findsOneWidget);

      await tester.tap(find.text('Adres Ekle'));
      await tester.pumpAndSettle();

      expect(find.text('adres sahnesi'), findsOneWidget);
      expect(opened.single, isA<CurrentUser>());
    },
  );

  testWidgets('adresi olan işverende çağrı yerine adres görünür', (
    tester,
  ) async {
    final opened = <Object?>[];
    await pumpProfile(tester, address: _address, opened: opened);

    expect(find.byKey(const ValueKey('profile-missing-address')), findsNothing);
    expect(find.text('Moda Caddesi 12, Caferağa Mahallesi'), findsOneWidget);
  });
}
