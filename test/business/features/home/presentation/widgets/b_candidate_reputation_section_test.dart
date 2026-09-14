import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/widgets/b_candidate_reputation_section.dart';
import 'package:koala/employee/features/auth/models/user_badge.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';
import 'package:koala/employee/features/jobs/models/review.dart';

import '../../../../../support/pump.dart';

void main() {
  const summary = RatingSummary(
    userId: 'worker-1',
    reviewCount: 12,
    averageRating: 4.5,
  );
  final reviews = [
    Review(
      id: 'review-1',
      rating: 5,
      comment: 'Çok titiz çalıştı.',
      author: const JobCreator(
        id: 'employer-1',
        firstName: 'Mehmet',
        lastName: 'Kaya',
      ),
      createdAt: DateTime(2026, 9, 1),
    ),
    const Review(id: 'review-2', rating: 3, isAnonymous: true),
  ];
  const badges = [
    UserBadge(
      code: 'RATING_GOLD',
      name: 'Beş Yıldız',
      family: BadgeFamily.rating,
      tier: BadgeTier.gold,
    ),
    UserBadge(code: 'IDENTITY', name: 'Kimliği Doğrulandı'),
  ];

  for (final brightness in Brightness.values) {
    testWidgets(
      'puan, tamamlanan iş, rozet ve yorumları çizer (${brightness.name})',
      (tester) async {
        await pumpInApp(
          tester,
          SingleChildScrollView(
            child: BCandidateReputationSection(
              summary: summary,
              reviews: reviews,
              badges: badges,
              completedJobCount: 7,
              isLoading: false,
              onRetry: () {},
            ),
          ),
          brightness: brightness,
        );

        expect(
          find.byKey(const ValueKey('candidate-rating-summary')),
          findsOneWidget,
        );
        expect(find.text('4.5'), findsOneWidget);
        expect(find.text('(12)'), findsOneWidget);
        expect(find.text('Tamamlanan iş: 7'), findsOneWidget);
        expect(find.text('Beş Yıldız · Altın'), findsOneWidget);
        expect(find.text('Kimliği Doğrulandı'), findsOneWidget);
        expect(find.text('Mehmet Kaya'), findsOneWidget);
        expect(find.text('Çok titiz çalıştı.'), findsOneWidget);
        expect(find.text('Anonim'), findsOneWidget);
        expect(find.byKey(const ValueKey('candidate-no-rating')), findsNothing);
        expect(
          find.byKey(const ValueKey('candidate-reputation-retry')),
          findsNothing,
        );
      },
    );
  }

  // Değerlendirmesi olmayan aday "0.0" değil "puan yok" görmeli; hiç rozeti
  // olmayan ile rozetleri henüz gelmemiş olan ayrı yazılmalı.
  testWidgets('boş durumları hatadan ayrı çizer', (tester) async {
    await pumpInApp(
      tester,
      SingleChildScrollView(
        child: BCandidateReputationSection(
          summary: const RatingSummary(userId: 'worker-1'),
          badges: const [],
          isLoading: false,
          onRetry: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('candidate-no-rating')), findsOneWidget);
    expect(find.text('0.0'), findsNothing);
    expect(find.byKey(const ValueKey('candidate-no-badges')), findsOneWidget);
    expect(find.byKey(const ValueKey('candidate-no-reviews')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('candidate-completed-jobs')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('candidate-reputation-retry')),
      findsNothing,
    );
  });

  testWidgets('hata şeridi eldeki veriyi silmez ve tekrar denetir', (
    tester,
  ) async {
    var retries = 0;
    await pumpInApp(
      tester,
      SingleChildScrollView(
        child: BCandidateReputationSection(
          summary: summary,
          badges: badges,
          isLoading: false,
          errorMessage: 'Değerlendirmeler alınamadı.',
          onRetry: () => retries++,
        ),
      ),
    );

    expect(find.text('Değerlendirmeler alınamadı.'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('Beş Yıldız · Altın'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('candidate-reputation-retry')));
    expect(retries, 1);
  });

  // Uç düştü ve yedek yok: "puan yok" / "rozet yok" demek yanlış olurdu.
  testWidgets('puan ve rozet ucu düşünce alınamadı yazar', (tester) async {
    await pumpInApp(
      tester,
      SingleChildScrollView(
        child: BCandidateReputationSection(
          summaryFailed: true,
          badgesFailed: true,
          isLoading: false,
          errorMessage: 'Sunucu hatası.',
          onRetry: () {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('candidate-rating-failed')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('candidate-no-rating')), findsNothing);
    expect(
      find.byKey(const ValueKey('candidate-badges-failed')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('candidate-no-badges')), findsNothing);
    expect(find.text('Rozetler yükleniyor...'), findsNothing);
  });

  testWidgets('rozetler yalnızca yüklenirken yükleniyor yazar', (tester) async {
    await pumpInApp(
      tester,
      SingleChildScrollView(
        child: BCandidateReputationSection(
          reviews: reviews,
          isLoading: true,
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('Rozetler yükleniyor...'), findsOneWidget);
  });

  testWidgets('yüklenirken bekleme halkası gösterir', (tester) async {
    await pumpInApp(
      tester,
      BCandidateReputationSection(isLoading: true, onRetry: () {}),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('candidate-no-rating')), findsNothing);
  });
}
