import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/core/widgets/identity_status_badge.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/settings/services/identity_document_service.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../support/fake_api.dart';
import '../../../support/finders.dart';
import '../../../support/identity_document_fixtures.dart';
import '../../../support/pump.dart';

CurrentUser _user({bool identityVerified = false}) => CurrentUser.fromJson({
  'id': 'user-1',
  'firstName': 'Çağrı',
  'lastName': 'Kaya',
  'email': 'cagri@ornek.com',
  'isEmployer': false,
  'identityVerified': identityVerified,
});

void main() {
  Future<(FakeApi, GoRouter)> pumpBadge(
    WidgetTester tester, {
    required FakeApiResponse review,
    bool identityVerified = false,
    Brightness brightness = Brightness.light,
  }) async {
    final api = FakeApi(handler: (_) => review);
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => Scaffold(
            body: IdentityStatusBadge(
              user: _user(identityVerified: identityVerified),
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
      ChangeNotifierProvider(
        create: (_) => IdentityReviewProvider(
          service: IdentityDocumentService.withClient(api.client),
        ),
        child: MaterialApp.router(
          theme: brightness == Brightness.dark ? darkTheme : lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (api, router);
  }

  group('durumlar', () {
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

    testWidgets('rozet çizilirken inceleme kendiliğinden okunuyor', (
      tester,
    ) async {
      final (api, _) = await pumpBadge(
        tester,
        review: identityReviewResponse(status: 'PENDING'),
      );

      expect(
        api.requests.map((request) => request.path),
        contains('/users/me/identity-documents'),
      );
    });

    testWidgets('doğrulanmış kullanıcı için inceleme sorulmuyor', (
      tester,
    ) async {
      // Bayrak son söz; ağa gitmenin anlamı yok.
      final (api, _) = await pumpBadge(
        tester,
        review: identityReviewResponse(status: 'REJECTED'),
        identityVerified: true,
      );

      expect(api.requests, isEmpty);
      expect(find.text(IdentityStatus.verified.label), findsOneWidget);
    });
  });

  group('dokunma', () {
    testWidgets('doğrulanmamış rozet kimlik ekranını açıyor', (tester) async {
      await pumpBadge(tester, review: noIdentityReviewResponse);

      await tester.tap(find.text(IdentityStatus.unverified.label));
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

  testWidgets('provider yokken yalnız bayrağa göre çiziliyor', (tester) async {
    // İş tarafı testleri farklı provider kümesiyle kuruluyor; rozet
    // provider'sız düşmemeli.
    await pumpInApp(tester, IdentityStatusBadge(user: _user()));

    expect(tester.takeException(), isNull);
    expect(find.text(IdentityStatus.unverified.label), findsOneWidget);
  });
}
