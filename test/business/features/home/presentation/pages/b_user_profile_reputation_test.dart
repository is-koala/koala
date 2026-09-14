import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/business/features/home/presentation/pages/b_user_profile_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_talent_pool_provider.dart';
import 'package:koala/business/features/home/services/b_candidate_profile_service.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/product/services/availability_service.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

const _applicant = JobApplicant(
  id: 'application-1',
  status: ApplicationStatus.applied,
  user: JobCreator(id: 'worker-1', firstName: 'Ayşe', lastName: 'Yılmaz'),
);

const _profileJson = {
  'id': 'worker-1',
  'firstName': 'Ayşe',
  'lastName': 'Yılmaz',
  'jobTitle': 'Barista',
};

const _badgeJson = {
  'code': 'GEZGIN_GOLD',
  'family': 'GEZGIN',
  'tier': 'GOLD',
  'name': 'Gezgin',
};

FakeApiResponse _ok(Object? data) =>
    FakeApiResponse(statusCode: 200, body: {'success': true, 'data': data});

const _failed = FakeApiResponse(
  statusCode: 500,
  body: {'success': false, 'message': 'Sunucu hatası.'},
);

/// Uçları yola göre yanıtlayan tek sahte sunucu; her uç ayrı ayrı
/// düşürülebiliyor.
Future<FakeApi> _pumpProfile(
  WidgetTester tester, {
  required Brightness brightness,
  Map<String, Object?> profile = _profileJson,
  FakeApiResponse? Function(RequestOptions request)? override,
}) async {
  final api = FakeApi(
    handler: (request) {
      final overridden = override?.call(request);
      if (overridden != null) return overridden;
      return switch (request.path) {
        '/users/worker-1' => _ok(profile),
        '/users/worker-1/availability' => _ok(const {
          'slots': [],
          'exceptions': [],
        }),
        '/users/worker-1/rating-summary' => _ok(const {
          'userId': 'worker-1',
          'reviewCount': 12,
          'averageRating': 4.5,
        }),
        '/users/worker-1/reviews' => _ok(const {
          'content': [
            {
              'id': 'review-1',
              'rating': 5,
              'comment': 'Çok titiz çalıştı.',
              'author': {
                'id': 'employer-1',
                'firstName': 'Mehmet',
                'lastName': 'Kaya',
              },
              'createdAt': '2026-09-01T10:00:00Z',
            },
          ],
          'last': true,
        }),
        '/users/worker-1/badges' => _ok(const [_badgeJson]),
        _ => _ok(const []),
      };
    },
  );

  await pumpInApp(
    tester,
    ChangeNotifierProvider(
      create: (_) => BTalentPoolProvider(),
      child: BUserProfilePage(
        applicant: _applicant,
        profileService: BCandidateProfileService.withClient(api.client),
        availabilityService: AvailabilityService.withClient(api.client),
        reviewService: ReviewService.withClient(api.client),
      ),
    ),
    brightness: brightness,
  );
  for (var index = 0; index < 20; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
  return api;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'puan, son yorumlar ve rozetler mevcut uçlardan gelir (${brightness.name})',
      (tester) async {
        final api = await _pumpProfile(tester, brightness: brightness);

        final paths = api.requests.map((request) => request.path).toList();
        expect(paths, contains('/users/worker-1/rating-summary'));
        expect(paths, contains('/users/worker-1/reviews'));
        expect(paths, contains('/users/worker-1/badges'));
        expect(
          api.requests
              .firstWhere((request) => request.path.endsWith('/reviews'))
              .queryParameters['size'],
          3,
        );

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('candidate-review-review-1')),
          200,
        );
        expect(find.text('4.5'), findsOneWidget);
        expect(find.text('(12)'), findsOneWidget);
        expect(find.text('Gezgin · Altın'), findsOneWidget);
        expect(find.text('Çok titiz çalıştı.'), findsOneWidget);
        // Eski sunucu profilde tamamlanan iş sayısını göndermiyor; satır yok.
        expect(
          find.byKey(const ValueKey('candidate-completed-jobs')),
          findsNothing,
        );
      },
    );
  }

  // koala-backend#282 profil yanıtına tamamlanan iş sayısını ekliyor.
  testWidgets('profil yanıtındaki tamamlanan iş sayısını yazar', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      brightness: Brightness.light,
      profile: const {
        ..._profileJson,
        'completedJobCount': 7,
        'averageRating': 4.5,
        'reviewCount': 12,
        'badges': [_badgeJson],
      },
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('candidate-completed-jobs')),
      200,
    );
    expect(find.text('Tamamlanan iş: 7'), findsOneWidget);
  });

  // Rozet ucu düşse de profil yanıtı aynı listeyi taşıyorsa rozetler çizilir;
  // yorumlar geldiği için hata şeridi de yok.
  testWidgets('rozet ucu düşünce profildeki kopyaya düşer', (tester) async {
    await _pumpProfile(
      tester,
      brightness: Brightness.dark,
      profile: const {
        ..._profileJson,
        'badges': [_badgeJson],
      },
      override: (request) => request.path.endsWith('/badges') ? _failed : null,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('candidate-badge-GEZGIN_GOLD')),
      200,
    );
    expect(find.text('Gezgin · Altın'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('candidate-reputation-retry')),
      findsNothing,
    );
  });

  testWidgets('yorum ucu düşünce şerit çıkar, puan yerinde kalır', (
    tester,
  ) async {
    final api = await _pumpProfile(
      tester,
      brightness: Brightness.light,
      override: (request) => request.path.endsWith('/reviews') ? _failed : null,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('candidate-reputation-retry')),
      200,
    );
    expect(find.text('Sunucu hatası.'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);

    final before = api.requests
        .where((request) => request.path.endsWith('/reviews'))
        .length;
    await tester.tap(find.byKey(const ValueKey('candidate-reputation-retry')));
    for (var index = 0; index < 20; index++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(
      api.requests.where((request) => request.path.endsWith('/reviews')).length,
      before + 1,
    );
  });
}
