import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/review.dart'
    show Review, ReviewSide, ReviewSubject;
import 'package:koala/employee/features/jobs/presentation/pages/review_page.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

const _employerSubject = ReviewSubject(
  assignmentId: 'assignment-1',
  side: ReviewSide.employer,
  title: 'Ayşe Yılmaz',
  subtitle: 'Barista',
  date: '10 Eyl 2026',
);

const _workerSubject = ReviewSubject(
  assignmentId: 'assignment-1',
  side: ReviewSide.worker,
  title: 'Barista',
  subtitle: 'Kahve Dükkânı',
  date: '10 Eyl 2026',
);

Future<FakeApi> pumpReview(
  WidgetTester tester, {
  required ReviewSubject subject,
  Brightness brightness = Brightness.light,
  FakeApiResponse Function(RequestOptions request)? handler,
}) async {
  final api = FakeApi(
    handler: (request) =>
        handler?.call(request) ??
        const FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': {'id': 'rev_1', 'rating': 4},
          },
        ),
  );
  await pumpInApp(
    tester,
    ChangeNotifierProvider(
      create: (_) =>
          ReviewProvider(service: ReviewService.withClient(api.client)),
      child: ReviewPage(subject: subject),
    ),
    brightness: brightness,
  );
  await tester.pumpAndSettle();
  return api;
}

final _submit = find.text('Yorumu Yayınla');
final _fourthStar = find.byIcon(Icons.star_border_rounded).at(3);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brightness in Brightness.values) {
    testWidgets('işveren tarafı: çalışanın kartı, anonim seçeneği yok '
        '(${brightness.name})', (tester) async {
      await pumpReview(
        tester,
        subject: _employerSubject,
        brightness: brightness,
      );

      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Barista'), findsOneWidget);
      expect(
        find.text('Çalışanla deneyiminizi nasıl değerlendirirsiniz?'),
        findsOneWidget,
      );
      expect(find.text('Yayınlama Tercihi'), findsNothing);
      expect(find.text('Anonim Yayınla'), findsNothing);
    });
  }

  testWidgets('çalışan tarafı anonim seçeneğini korur', (tester) async {
    await pumpReview(tester, subject: _workerSubject);

    expect(find.text('Kahve Dükkânı'), findsOneWidget);
    expect(
      find.text('Bu iş deneyiminizi nasıl değerlendirirsiniz?'),
      findsOneWidget,
    );
    expect(find.text('Anonim Yayınla'), findsOneWidget);
  });

  // Yorum sınırı sunucununki: `CreateReviewDto.comment` `@Size(max = 2000)`.
  testWidgets('yorum alanı backend sınırını taşır', (tester) async {
    await pumpReview(tester, subject: _employerSubject);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, Review.maxCommentLength);
    expect(field.maxLength, 2000);
  });

  testWidgets('işveren gönderimi atama ucuna gider, anonim false', (
    tester,
  ) async {
    Map<String, dynamic>? body;
    String? path;
    await pumpReview(
      tester,
      subject: _employerSubject,
      handler: (request) {
        path = request.path;
        body = request.data as Map<String, dynamic>;
        return const FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': {'id': 'rev_1', 'rating': 4, 'comment': 'Dakik'},
          },
        );
      },
    );

    await tester.tap(_fourthStar);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Dakik');
    await tester.tap(_submit);
    // Toast zamanlayıcıyla kapanıyor; settle yerine birkaç kare.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(path, '/job-assignments/assignment-1/reviews');
    expect(body, {'rating': 4, 'comment': 'Dakik', 'anonymous': false});
    expect(find.text('Değerlendirmeniz gönderildi!'), findsOneWidget);
  });

  testWidgets('puansız gönderim uyarır, istek atmaz', (tester) async {
    final api = await pumpReview(tester, subject: _employerSubject);

    await tester.tap(_submit);
    await tester.pump();

    expect(find.text('Lütfen bir puan verin'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  // Hata toast'ı sunucunun mesajını taşıyor; 409 "zaten değerlendirilmiş"
  // provider'ı işaretliyor, ekran kapanmıyor.
  testWidgets('sunucu reddi backend mesajıyla gösterilir', (tester) async {
    await pumpReview(
      tester,
      subject: _employerSubject,
      handler: (_) => const FakeApiResponse(
        statusCode: 409,
        body: {
          'success': false,
          'message': 'Bu iş için zaten değerlendirme yaptınız.',
          'errorCode': 'REVIEW_ALREADY_REVIEWED',
          'errorCategory': 'DATA_CONFLICT',
        },
      ),
    );

    await tester.tap(_fourthStar);
    await tester.pump();
    await tester.tap(_submit);
    await tester.pumpAndSettle();

    expect(
      find.text('Bu iş için zaten değerlendirme yaptınız.'),
      findsOneWidget,
    );
    expect(find.byType(ReviewPage), findsOneWidget);
    final provider = tester
        .element(find.byType(ReviewPage))
        .read<ReviewProvider>();
    expect(provider.hasReviewed('assignment-1'), isTrue);
  });
}
