import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/settings/services/identity_document_service.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/widgets/identity_status_badge.dart';
import 'package:provider/provider.dart';

import '../../support/fake_api.dart';
import '../../support/finders.dart';
import '../../support/identity_document_fixtures.dart';

CurrentUser _user({bool identityVerified = false}) => CurrentUser.fromJson({
  'id': 'user-1',
  'firstName': 'Çağrı',
  'lastName': 'Kaya',
  'email': 'cagri@ornek.com',
  'isEmployer': false,
  'identityVerified': identityVerified,
});

void main() {
  /// Rozet kendi okumasını başlatmıyor; profil sayfası gibi burada da
  /// provider önce doldurulup sonra çiziliyor.
  Future<GoRouter> pumpBadge(
    WidgetTester tester, {
    required FakeApiResponse review,
    bool identityVerified = false,
    bool onAccentSurface = false,
    Brightness brightness = Brightness.light,
  }) async {
    final api = FakeApi(handler: (_) => review);
    final provider = IdentityReviewProvider(
      service: IdentityDocumentService.withClient(api.client),
    );
    await tester.runAsync(() => provider.load(silent: true));

    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => Scaffold(
            body: ColoredBox(
              color: onAccentSurface
                  ? AppColors.primaryColor
                  : Colors.transparent,
              child: IdentityStatusBadge(
                user: _user(identityVerified: identityVerified),
                onAccentSurface: onAccentSurface,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/identity-verification',
          builder: (context, state) =>
              const Scaffold(body: Text('kimlik ekranı')),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp.router(
          theme: brightness == Brightness.dark ? darkTheme : lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  final cases = <(String, FakeApiResponse, IdentityStatus, String)>[
    (
      'inceleme yok',
      noIdentityReviewResponse,
      IdentityStatus.unverified,
      AppIcons.alert,
    ),
    (
      'bekliyor',
      identityReviewResponse(status: 'PENDING'),
      IdentityStatus.pending,
      AppIcons.clock,
    ),
    (
      'reddedildi',
      identityReviewResponse(status: 'REJECTED'),
      IdentityStatus.rejected,
      AppIcons.cancelCircle,
    ),
    (
      'onaylandı',
      identityReviewResponse(status: 'APPROVED'),
      IdentityStatus.verified,
      AppIcons.checkCircle,
    ),
  ];

  group('durumlar', () {
    for (final brightness in Brightness.values) {
      for (final (name, review, status, icon) in cases) {
        testWidgets(
          '${brightness.name} temada $name kendi etiketi ve ikonuyla',
          (tester) async {
            await pumpBadge(tester, review: review, brightness: brightness);

            expect(tester.takeException(), isNull);
            expect(find.text(status.label), findsOneWidget);
            expect(findAppIcon(icon), findsOneWidget);
          },
        );
      }
    }

    testWidgets('bayrak doğrulandı diyorsa reddedilmiş inceleme bile '
        'doğrulanmış gösteriyor', (tester) async {
      await pumpBadge(
        tester,
        review: identityReviewResponse(status: 'REJECTED'),
        identityVerified: true,
      );

      expect(find.text(IdentityStatus.verified.label), findsOneWidget);
    });

    testWidgets('yeşil kapak üstünde beyaz varyant; dört durum da çiziliyor', (
      tester,
    ) async {
      for (final (_, review, status, _) in cases) {
        await pumpBadge(tester, review: review, onAccentSurface: true);

        expect(tester.takeException(), isNull, reason: status.name);
        final label = tester.widget<Text>(find.text(status.label));
        expect(label.style?.color, AppColors.onAccent, reason: status.name);
      }
    });
  });

  group('dokunma', () {
    testWidgets('doğrulanmamış rozet kimlik ekranını açıyor', (tester) async {
      await pumpBadge(tester, review: noIdentityReviewResponse);

      await tester.tap(find.text(IdentityStatus.unverified.label));
      await tester.pumpAndSettle();

      expect(find.text('kimlik ekranı'), findsOneWidget);
    });

    testWidgets('reddedilmiş rozet kimlik ekranını açıyor', (tester) async {
      await pumpBadge(
        tester,
        review: identityReviewResponse(status: 'REJECTED'),
      );

      await tester.tap(find.text(IdentityStatus.rejected.label));
      await tester.pumpAndSettle();

      expect(find.text('kimlik ekranı'), findsOneWidget);
    });

    testWidgets('bekleyen rozet de kimlik ekranını açıyor (durum orada)', (
      tester,
    ) async {
      await pumpBadge(
        tester,
        review: identityReviewResponse(status: 'PENDING'),
      );

      await tester.tap(find.text(IdentityStatus.pending.label));
      await tester.pumpAndSettle();

      expect(find.text('kimlik ekranı'), findsOneWidget);
    });

    testWidgets('doğrulanmış rozet düz etiket', (tester) async {
      await pumpBadge(
        tester,
        review: noIdentityReviewResponse,
        identityVerified: true,
      );

      expect(find.byType(InkWell), findsNothing);
      await tester.tap(find.text(IdentityStatus.verified.label));
      await tester.pumpAndSettle();
      expect(find.text('kimlik ekranı'), findsNothing);
    });
  });

  testWidgets('provider sonradan red okuyunca rozet yerinde güncelleniyor', (
    tester,
  ) async {
    // Profil sayfası her açılışta provider'ı tazeliyor; rozet o
    // bildirimle yeniden çizilmeli, açılıştaki değerde kalmamalı.
    var status = 'PENDING';
    final api = FakeApi(handler: (_) => identityReviewResponse(status: status));
    final provider = IdentityReviewProvider(
      service: IdentityDocumentService.withClient(api.client),
    );
    await tester.runAsync(() => provider.load(silent: true));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: lightTheme,
          home: Scaffold(body: IdentityStatusBadge(user: _user())),
        ),
      ),
    );
    expect(find.text(IdentityStatus.pending.label), findsOneWidget);

    status = 'REJECTED';
    await tester.runAsync(() => provider.load(silent: true));
    await tester.pump();

    expect(find.text(IdentityStatus.rejected.label), findsOneWidget);
  });
}
