import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/pages/b_payment_result_page.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/product/theme/theme.dart';

import '../../../../../support/fake_api.dart';

void main() {
  testWidgets('ödeme sonucu query yerine backend atama durumundan gösterilir', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'content': [
              {
                'id': 'asg_1',
                'status': 'CONFIRMED',
                'paymentStatus': 'HELD_IN_ESCROW',
                'job': {
                  'id': 'job_1',
                  'title': 'Barista',
                  'salary': 1500,
                  'category': {
                    'id': 'cat_1',
                    'code': 'BARISTA',
                    'name': 'Barista',
                  },
                },
              },
            ],
          },
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: BPaymentResultPage(
          assignmentId: 'asg_1',
          service: EmployerJobService.withClient(api.client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ödeme Güvende'), findsOneWidget);
    expect(find.textContaining('başarısız'), findsNothing);
  });

  testWidgets('kesin ret bekleme yerine yeniden deneme olarak gösterilir', (
    tester,
  ) async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'content': [
              {
                'id': 'asg_1',
                'status': 'CONFIRMED',
                'paymentStatus': 'FAILED',
                'job': {
                  'id': 'job_1',
                  'title': 'Barista',
                  'salary': 1500,
                  'category': {
                    'id': 'cat_1',
                    'code': 'BARISTA',
                    'name': 'Barista',
                  },
                },
              },
            ],
          },
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: BPaymentResultPage(
          assignmentId: 'asg_1',
          service: EmployerJobService.withClient(api.client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ödeme Başarısız'), findsOneWidget);
    expect(find.textContaining('yeniden deneyebilirsin'), findsOneWidget);
    expect(find.text('Ödeme Henüz Doğrulanmadı'), findsNothing);
  });
}
