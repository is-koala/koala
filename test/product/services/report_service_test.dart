import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/services/report_service.dart';

import '../../support/fake_api.dart';

/// `POST /reports` yanıtı. Testlerin çoğu gövdeyi değil isteği doğruluyor,
/// bu yüzden tek bir hazır yanıt yetiyor.
const _createdReport = FakeApiResponse(
  statusCode: 201,
  body: {
    'success': true,
    'data': {
      'id': 'r1',
      'reportedUserId': 'u9',
      'reason': 'HARASSMENT',
      'status': 'OPEN',
      'createdAt': '2026-02-15T09:00:00',
    },
  },
);

void main() {
  group('ReportService.createReport', () {
    test('şikayet /reports yoluna gider', () async {
      final api = FakeApi(handler: (_) => _createdReport);

      await ReportService.withClient(
        api.client,
      ).createReport(reportedUserId: 'u9', reason: ReportReason.harassment);

      expect(api.requests.single.path, '/reports');
      expect(api.requests.single.method, 'POST');
    });

    test('kullanıcı şikayeti gövdeye reportedUserId olarak konur', () async {
      final api = FakeApi(handler: (_) => _createdReport);

      await ReportService.withClient(api.client).createReport(
        reportedUserId: 'u9',
        reason: ReportReason.fakeProfile,
        description: 'Sahte profil',
      );

      expect(api.requests.single.data, {
        'reportedUserId': 'u9',
        'reason': 'FAKE_PROFILE',
        'description': 'Sahte profil',
      });
    });

    test('ilan şikayeti gövdeye jobId olarak konur', () async {
      final api = FakeApi(handler: (_) => _createdReport);

      await ReportService.withClient(
        api.client,
      ).createReport(jobId: 'j7', reason: ReportReason.offPlatformPayment);

      expect(api.requests.single.data, {
        'jobId': 'j7',
        'reason': 'OFF_PLATFORM_PAYMENT',
      });
    });

    test('mesaj şikayeti gövdeye messageId olarak konur', () async {
      final api = FakeApi(handler: (_) => _createdReport);

      await ReportService.withClient(
        api.client,
      ).createReport(messageId: 'm3', reason: ReportReason.spam);

      expect(api.requests.single.data, {'messageId': 'm3', 'reason': 'SPAM'});
    });

    test('görsel şikayeti gövdeye imageId olarak konur', () async {
      final api = FakeApi(handler: (_) => _createdReport);

      await ReportService.withClient(
        api.client,
      ).createReport(imageId: 'i2', reason: ReportReason.inappropriateContent);

      expect(api.requests.single.data, {
        'imageId': 'i2',
        'reason': 'INAPPROPRIATE_CONTENT',
      });
    });

    test('verilmeyen hedef alanları gövdede hiç bulunmaz', () async {
      final api = FakeApi(handler: (_) => _createdReport);

      await ReportService.withClient(
        api.client,
      ).createReport(reportedUserId: 'u9', reason: ReportReason.harassment);

      final body = api.requests.single.data! as Map<String, dynamic>;

      expect(body.containsKey('jobId'), isFalse);
      expect(body.containsKey('messageId'), isFalse);
      expect(body.containsKey('imageId'), isFalse);
      expect(body.containsKey('description'), isFalse);
    });

    test('yanıt Report modeline çevrilir', () async {
      final api = FakeApi(handler: (_) => _createdReport);

      final report = await ReportService.withClient(
        api.client,
      ).createReport(reportedUserId: 'u9', reason: ReportReason.harassment);

      expect(report.id, 'r1');
      expect(report.reportedUserId, 'u9');
      expect(report.reason, ReportReason.harassment);
      expect(report.status, ReportStatus.open);
    });
  });

  group('ReportService.fetchMyReports', () {
    FakeApiResponse pageResponse() => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'content': [
            {
              'id': 'r1',
              'jobId': 'j7',
              'reason': 'NO_SHOW',
              'status': 'UNDER_REVIEW',
              'createdAt': '2026-02-15T09:00:00',
            },
            {
              'id': 'r2',
              'messageId': 'm3',
              'reason': 'SPAM',
              'status': 'DISMISSED',
              'description': 'Reklam',
              'reviewNote': 'Geçerli bulunmadı',
              'createdAt': '2026-02-14T09:00:00',
            },
          ],
          'page': 0,
          'size': 20,
          'totalElements': 2,
          'totalPages': 1,
          'first': true,
          'last': true,
        },
      },
    );

    test('liste /reports/me yolundan sayfayla gelir', () async {
      final api = FakeApi(handler: (_) => pageResponse());

      final page = await ReportService.withClient(api.client).fetchMyReports();

      expect(api.requests.single.path, '/reports/me');
      expect(api.requests.single.queryParameters['page'], 0);
      expect(page.reports, hasLength(2));
      expect(page.reports.first.reason, ReportReason.noShow);
      expect(page.reports.first.status, ReportStatus.underReview);
      expect(page.reports.last.reviewNote, 'Geçerli bulunmadı');
      expect(page.totalElements, 2);
      expect(page.last, isTrue);
    });

    test('istenen sayfa numarası sorguya konur', () async {
      final api = FakeApi(handler: (_) => pageResponse());

      await ReportService.withClient(api.client).fetchMyReports(page: 2);

      expect(api.requests.single.queryParameters['page'], 2);
    });

    test('boş sayfa boş liste verir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': [], 'totalElements': 0, 'last': true},
          },
        ),
      );

      final page = await ReportService.withClient(api.client).fetchMyReports();

      expect(page.reports, isEmpty);
      expect(page.last, isTrue);
    });

    test('tanınmayan gerekçe ve durum uygulamayı düşürmez', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                {
                  'id': 'r9',
                  'reportedUserId': 'u1',
                  'reason': 'MIND_READING',
                  'status': 'ESCALATED',
                  'createdAt': '2026-02-15T09:00:00',
                },
              ],
              'last': true,
            },
          },
        ),
      );

      final page = await ReportService.withClient(api.client).fetchMyReports();

      expect(page.reports.single.reason, ReportReason.unknown);
      expect(page.reports.single.status, ReportStatus.unknown);
    });
  });
}
