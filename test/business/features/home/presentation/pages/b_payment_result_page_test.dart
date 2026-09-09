import 'dart:async';

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
            'id': 'asg_1',
            'status': 'CONFIRMED',
            'paymentStatus': 'HELD_IN_ESCROW',
            'job': {
              'id': 'job_1',
              'title': 'Barista',
              'salary': 1500,
              'category': {'id': 'cat_1', 'code': 'BARISTA', 'name': 'Barista'},
            },
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
    expect(api.requests, hasLength(1));
    expect(api.requests.single.path, '/job-assignments/asg_1');
    expect(api.requests.single.method, 'GET');
    expect(api.requests.single.queryParameters, isEmpty);
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
            'id': 'asg_1',
            'status': 'CONFIRMED',
            'paymentStatus': 'FAILED',
            'job': {
              'id': 'job_1',
              'title': 'Barista',
              'salary': 1500,
              'category': {'id': 'cat_1', 'code': 'BARISTA', 'name': 'Barista'},
            },
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

  for (final error in [
    (status: 404, message: 'İş kaydı bulunamadı.'),
    (status: 500, message: 'Sunucu geçici olarak kullanılamıyor.'),
  ]) {
    testWidgets('${error.status} hatası yeniden deneme yüzeyinde gösterilir', (
      tester,
    ) async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: error.status,
          body: {'success': false, 'message': error.message},
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

      expect(find.text(error.message), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Ödeme Henüz Doğrulanmadı'), findsOneWidget);
      expect(find.text('TEKRAR KONTROL ET'), findsOneWidget);
      expect(find.text('İLANA DÖN'), findsNothing);
      expect(api.requests.single.path, '/job-assignments/asg_1');
    });
  }

  testWidgets('yanıt gelene kadar yükleniyor durumu korunuyor', (tester) async {
    final response = Completer<FakeApiResponse>();
    final api = FakeApi(handler: (_) => response.future);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: BPaymentResultPage(
          assignmentId: 'asg_1',
          service: EmployerJobService.withClient(api.client),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Ödeme Güvende'), findsNothing);

    response.complete(
      const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'id': 'asg_1',
            'status': 'CONFIRMED',
            'paymentStatus': 'HELD_IN_ESCROW',
            'job': {
              'id': 'job_1',
              'title': 'Barista',
              'salary': 1500,
              'category': {'id': 'cat_1', 'code': 'BARISTA', 'name': 'Barista'},
            },
          },
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Ödeme Güvende'), findsOneWidget);
  });
}
