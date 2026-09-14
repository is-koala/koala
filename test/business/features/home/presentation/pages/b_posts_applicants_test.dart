import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/pages/b_posts_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

const _pastJob = {
  'id': 'job-1',
  'title': 'Barista',
  'salary': 1000,
  'status': 'CLOSED',
  'applicationCount': 1,
  'category': {'id': 'category-1', 'code': 'BARISTA', 'name': 'Barista'},
};

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('geçmiş ilan başvuru hatasını elle yeniden dener '
        '(${brightness.name})', (tester) async {
      var applicantRequestCount = 0;
      final api = FakeApi(
        handler: (request) {
          if (request.path == '/users/me/jobs') {
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'content': [_pastJob],
                },
              },
            );
          }

          applicantRequestCount++;
          if (applicantRequestCount == 1) {
            return const FakeApiResponse(
              statusCode: 500,
              body: {'success': false, 'message': 'Yapan kişi alınamadı'},
            );
          }
          return const FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': [
                {
                  'id': 'application-1',
                  'status': 'ACCEPTED',
                  'applicationDateTime': '2026-09-08T10:00:00Z',
                  'applicant': {
                    'id': 'worker-1',
                    'firstName': 'Ayşe',
                    'lastName': 'Yılmaz',
                  },
                },
              ],
            },
          );
        },
      );
      final provider = BJobsProvider(
        service: EmployerJobService.withClient(api.client),
      );
      await tester.runAsync(provider.load);

      await pumpInApp(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            // Kart, çok şirketli kullanıcıda şirket adını yazmak için oturum
            // sahibine bakıyor; bu test o satırı sınamıyor, kullanıcı boş.
            ChangeNotifierProvider(create: (_) => UserProvider()),
          ],
          child: const BPostsPage(),
        ),
        brightness: brightness,
      );
      for (var index = 0; index < 20; index++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.tap(find.text('Geçmiş (1)'));
      await tester.pumpAndSettle();

      expect(applicantRequestCount, 1);
      expect(find.text('Yapan kişi alınamadı'), findsOneWidget);
      expect(find.text('Yapan kişi bilgisi yok'), findsNothing);

      final retry = find.byKey(const ValueKey('post-applicants-retry-job-1'));
      await tester.tap(retry);
      for (var index = 0; index < 20; index++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(applicantRequestCount, 2);
      expect(find.text('Yapan kişi alınamadı'), findsNothing);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    });
  }
}
