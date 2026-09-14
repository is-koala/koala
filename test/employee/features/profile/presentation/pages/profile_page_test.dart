import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/employee/features/profile/presentation/pages/profile_page.dart';
import 'package:koala/employee/features/profile/presentation/providers/availability_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/settings/services/identity_document_service.dart';
import 'package:koala/product/services/availability_service.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/identity_document_fixtures.dart';

const Map<String, dynamic> _me = {
  'id': 'user-1',
  'firstName': 'Çağrı',
  'lastName': 'Kaya',
  'email': 'cagri@ornek.com',
  'isEmployer': false,
  'identityVerified': false,
};

void main() {
  /// Profil sayfasının açılışta vurduğu her uç: kullanıcı, kimlik incelemesi,
  /// müsaitlik, değerlendirmeler. İnceleme yanıtı [review] ile değişiyor.
  FakeApi serverWith(FakeApiResponse Function() review) {
    return FakeApi(
      handler: (options) {
        switch (options.path) {
          case '/users/me':
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': _me},
            );
          case '/users/me/identity-documents':
            return review();
          case '/users/user-1/rating-summary':
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': null},
            );
          case '/users/user-1/reviews':
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {'content': [], 'last': true, 'totalElements': 0},
              },
            );
          default:
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': []},
            );
        }
      },
    );
  }

  Future<IdentityReviewProvider> pumpProfile(
    WidgetTester tester,
    FakeApi api, {
    IdentityReviewProvider? reviews,
  }) async {
    final reviewProvider =
        reviews ??
        IdentityReviewProvider(
          service: IdentityDocumentService.withClient(api.client),
        );
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              ProfilePage(reviewService: ReviewService.withClient(api.client)),
        ),
        GoRoute(
          path: '/identity-verification',
          builder: (context, state) =>
              const Scaffold(body: Text('kimlik ekranı')),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>(
            create: (_) =>
                UserProvider(userService: UserService.withClient(api.client)),
          ),
          ChangeNotifierProvider<AvailabilityProvider>(
            create: (_) => AvailabilityProvider(
              service: AvailabilityService.withClient(api.client),
            ),
          ),
          ChangeNotifierProvider<IdentityReviewProvider>.value(
            value: reviewProvider,
          ),
        ],
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return reviewProvider;
  }

  testWidgets('açılışta inceleme yeniden okunuyor: eski "bekliyor" yerine '
      'personelin reddi rozette', (tester) async {
    // Açılışta okunan kayıt bekliyordu; personel bu arada reddetti. Profil
    // her açılışta provider'ı tazelediği için rozet REJECTED gösteriyor.
    var status = 'PENDING';
    final api = serverWith(() => identityReviewResponse(status: status));
    final stale = IdentityReviewProvider(
      service: IdentityDocumentService.withClient(api.client),
    );
    await tester.runAsync(() => stale.load(silent: true));
    expect(stale.review?.isPending, isTrue);

    status = 'REJECTED';
    await pumpProfile(tester, api, reviews: stale);

    expect(find.text(IdentityStatus.rejected.label), findsOneWidget);
    expect(find.text(IdentityStatus.pending.label), findsNothing);
    expect(
      api.requests
          .where((r) => r.path == '/users/me/identity-documents')
          .length,
      2,
      reason: 'açılış provider\'ı sessizce yeniden sordu',
    );
  });

  testWidgets('hiç inceleme yokken rozet doğrulanmadı ve kimlik ekranını '
      'açıyor', (tester) async {
    await pumpProfile(tester, serverWith(() => noIdentityReviewResponse));

    expect(find.text(IdentityStatus.unverified.label), findsOneWidget);

    await tester.tap(find.text(IdentityStatus.unverified.label));
    await tester.pumpAndSettle();

    expect(find.text('kimlik ekranı'), findsOneWidget);
  });

  testWidgets('aşağı çekince inceleme de tazeleniyor', (tester) async {
    var status = 'PENDING';
    final api = serverWith(() => identityReviewResponse(status: status));
    await pumpProfile(tester, api);
    expect(find.text(IdentityStatus.pending.label), findsOneWidget);

    status = 'REJECTED';
    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text(IdentityStatus.rejected.label), findsOneWidget);
  });
}
