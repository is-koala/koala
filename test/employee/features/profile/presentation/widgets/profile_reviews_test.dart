import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_reviews.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

FakeApiResponse _ok(Object? data) =>
    FakeApiResponse(statusCode: 200, body: {'success': true, 'data': data});

FakeApi _server({Object? summary, List<Map<String, Object?>> reviews = const []}) {
  return FakeApi(
    handler: (options) {
      return switch (options.path) {
        '/users/user-1/rating-summary' => _ok(summary),
        '/users/user-1/reviews' => _ok({
          'content': reviews,
          'last': true,
          'totalElements': reviews.length,
        }),
        _ => _ok(null),
      };
    },
  );
}

Future<void> _pumpReviews(
  WidgetTester tester,
  FakeApi api, {
  Brightness brightness = Brightness.light,
}) {
  return pumpInApp(
    tester,
    SingleChildScrollView(
      child: ProfileReviews(
        userId: 'user-1',
        service: ReviewService.withClient(api.client),
      ),
    ),
    brightness: brightness,
  );
}

void main() {
  const summary = {
    'userId': 'user-1',
    'reviewCount': 12,
    'averageRating': 4.5,
  };
  const review = {
    'id': 'review-1',
    'rating': 5,
    'comment': 'Çok titiz çalıştı.',
    'author': {'id': 'employer-1', 'firstName': 'Mehmet', 'lastName': 'Kaya'},
  };

  for (final brightness in Brightness.values) {
    testWidgets(
      'kendi puanını ve yorum sayısını çizer (${brightness.name})',
      (tester) async {
        await _pumpReviews(
          tester,
          _server(summary: summary, reviews: [review]),
          brightness: brightness,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('profile-rating-summary')),
          findsOneWidget,
        );
        expect(find.text('4.5'), findsOneWidget);
        expect(find.text('(12)'), findsOneWidget);
        expect(find.text('Mehmet Kaya'), findsOneWidget);
        expect(find.text('Çok titiz çalıştı.'), findsOneWidget);
        expect(find.byKey(const ValueKey('profile-no-rating')), findsNothing);
        expect(find.text('0.0'), findsNothing);
      },
    );
  }

  // `/users/me` puan taşımıyor; özet ucu `data: null` dönünce sıfır yıldız
  // uydurulmamalı. Aday kartındaki "Henüz puan yok" ile aynı dürüst boşluk.
  testWidgets('değerlendirmesi yokken 0.0 yazmaz', (tester) async {
    await _pumpReviews(tester, _server());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-no-rating')), findsOneWidget);
    expect(find.text('Henüz puan yok'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-no-reviews')), findsOneWidget);
    expect(
      find.textContaining('Henüz değerlendirilmedin'),
      findsOneWidget,
    );
    expect(find.text('0.0'), findsNothing);
    expect(find.byKey(const ValueKey('profile-rating-summary')), findsNothing);
  });
}
