import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/product/features/account/account_routes.dart';

import '../../../../../support/fake_api.dart';
import 'b_job_detail_test_harness.dart';

/// Adresi olmayan bireysel işveren.
const _employer = {
  'id': 'employer-1',
  'firstName': 'Ayşe',
  'lastName': 'İşveren',
  'email': 'ayse@ornek.com',
  'isEmployer': true,
  'identityVerified': true,
  'companies': <Object>[],
};

void main() {
  // `JobAssignmentManager.initiatePaymentSession` bireysel işverenin adresi
  // yokken İyzico alıcı kaydını kuramıyor ve `400` + bu kodla dönüyor.
  // Mesaj ("İşverenin adres bilgisi eksik.") ne yapılacağını söylemiyor;
  // uygulama kullanıcıyı doğrudan adres ekranına götürmeli.
  testWidgets('adres eksik hatası işvereni adres ekranına götürür', (
    tester,
  ) async {
    final opened = <Object?>[];
    final harness = await pumpPage(
      tester,
      currentUser: _employer,
      employerHandler: (request) {
        if (request.method == 'POST') {
          return const FakeApiResponse(
            statusCode: 400,
            body: {
              'success': false,
              'message': 'İşverenin adres bilgisi eksik.',
              'errorCode': 'JOB_ASSIGNMENT_ADDRESS_NOT_PROVIDED_FOR_EMPLOYER',
              'errorCategory': 'VALIDATION_FAILED',
            },
          );
        }
        return const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [assignmentJson],
            },
          },
        );
      },
      extraRoutes: [
        GoRoute(
          path: AccountRoutes.address,
          pageBuilder: (context, state) {
            opened.add(state.extra);
            return const MaterialPage<void>(
              child: Scaffold(body: Text('adres sahnesi')),
            );
          },
        ),
      ],
    );

    final button = find.text('Güvenli Ödemeyi Tamamla');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ödemeye geç'));
    await tester.pumpAndSettle();

    expect(
      harness.employerApi.requests.where((request) => request.method == 'POST'),
      hasLength(1),
    );
    expect(harness.launches(), 0);
    expect(find.text('adres sahnesi'), findsOneWidget);
    expect(opened.single, isA<CurrentUser>());
  });

  // Aynı akışta ilanın adresi de eksik olabilir; o hata işverenin kendi
  // adres ekranıyla çözülmez, yalnız mesaj gösterilir.
  testWidgets('ilan adresi eksik hatası yönlendirmez', (tester) async {
    final opened = <Object?>[];
    await pumpPage(
      tester,
      currentUser: _employer,
      employerHandler: (request) {
        if (request.method == 'POST') {
          return const FakeApiResponse(
            statusCode: 400,
            body: {
              'success': false,
              'message': 'İlanın adres bilgisi eksik.',
              'errorCode': 'JOB_ASSIGNMENT_ADDRESS_NOT_PROVIDED_FOR_JOB',
              'errorCategory': 'VALIDATION_FAILED',
            },
          );
        }
        return const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [assignmentJson],
            },
          },
        );
      },
      extraRoutes: [
        GoRoute(
          path: AccountRoutes.address,
          pageBuilder: (context, state) {
            opened.add(state.extra);
            return const MaterialPage<void>(
              child: Scaffold(body: Text('adres sahnesi')),
            );
          },
        ),
      ],
    );

    final button = find.text('Güvenli Ödemeyi Tamamla');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ödemeye geç'));
    await tester.pumpAndSettle();

    expect(find.text('İlanın adres bilgisi eksik.'), findsOneWidget);
    expect(find.text('adres sahnesi'), findsNothing);
    expect(opened, isEmpty);
  });
}
