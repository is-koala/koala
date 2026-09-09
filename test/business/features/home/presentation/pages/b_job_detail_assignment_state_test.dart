import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../support/fake_api.dart';
import 'b_job_detail_test_harness.dart';

void main() {
  testWidgets(
    'atama isteği başlamadan doğrulanmamış durumu yükleniyor gösterir',
    (tester) async {
      final jobsResponse = Completer<FakeApiResponse>();
      await pumpPage(tester, settle: false, jobsResponse: jobsResponse);

      expect(find.text('İş Takibi'), findsOneWidget);
      expect(find.byKey(const ValueKey('assignment-loading')), findsOneWidget);
      expect(find.byKey(const ValueKey('assignment-load-error')), findsNothing);
      expect(find.byKey(const ValueKey('retry-assignment-load')), findsNothing);

      jobsResponse.complete(
        const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [jobJson],
            },
          },
        ),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('başarılı boş atama yanıtını yükleme hatası gibi göstermez', (
    tester,
  ) async {
    await pumpPage(tester, assignments: const []);

    expect(find.text('İş Takibi'), findsNothing);
    expect(find.byKey(const ValueKey('assignment-load-error')), findsNothing);
    expect(find.byKey(const ValueKey('retry-assignment-load')), findsNothing);
  });

  testWidgets('atama yükleme hatasını görünür ve tekrar denenebilir gösterir', (
    tester,
  ) async {
    await pumpPage(
      tester,
      employerHandler: (_) => const FakeApiResponse(
        statusCode: 500,
        body: {'success': false, 'message': 'Atama bilgileri alınamadı.'},
      ),
    );

    expect(find.text('İş Takibi'), findsOneWidget);
    expect(find.text('Atama bilgileri alınamadı.'), findsOneWidget);
    expect(find.byKey(const ValueKey('assignment-load-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-assignment-load')), findsOneWidget);
  });

  testWidgets('atama yükleme hatasını koyu temada da gösterir', (tester) async {
    await pumpPage(
      tester,
      brightness: Brightness.dark,
      employerHandler: (_) => const FakeApiResponse(
        statusCode: 500,
        body: {'success': false, 'message': 'Atama bilgileri alınamadı.'},
      ),
    );

    expect(find.text('Atama bilgileri alınamadı.'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-assignment-load')), findsOneWidget);
  });

  testWidgets(
    'yenileme hatasında güvenilir atamayı korur ve eylemleri kapatır',
    (tester) async {
      var refreshFails = false;
      await pumpPage(
        tester,
        employerHandler: (_) => refreshFails
            ? const FakeApiResponse(
                statusCode: 500,
                body: {
                  'success': false,
                  'message': 'Atama bilgileri güncellenemedi.',
                },
              )
            : const FakeApiResponse(
                statusCode: 200,
                body: {
                  'success': true,
                  'data': {
                    'content': [assignmentJson],
                  },
                },
              ),
      );

      expect(find.text('Onaylandı'), findsOneWidget);
      expect(find.text('Güvenli Ödemeyi Tamamla'), findsOneWidget);
      expect(find.text('İşi Tamamla'), findsOneWidget);
      expect(find.text('İşi İptal Et'), findsOneWidget);

      refreshFails = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Onaylandı'), findsOneWidget);
      expect(find.text('Atama bilgileri güncellenemedi.'), findsOneWidget);
      expect(find.text('Güvenli Ödemeyi Tamamla'), findsNothing);
      expect(find.text('İşi Tamamla'), findsNothing);
      expect(find.text('İşi İptal Et'), findsNothing);
      expect(find.text('Sorun Bildir'), findsNothing);
    },
  );

  testWidgets('tekrar deneme ilişkili durumu tek snapshot olarak yeniler', (
    tester,
  ) async {
    var assignmentFetchCount = 0;
    final workSessions = Completer<FakeApiResponse>();
    final refreshedAssignment = <String, Object?>{
      ...assignmentJson,
      'status': 'IN_PROGRESS',
      'paymentStatus': 'HELD_IN_ESCROW',
    };

    await pumpPage(
      tester,
      settle: false,
      employerHandler: (_) {
        assignmentFetchCount++;
        if (assignmentFetchCount == 1) {
          return const FakeApiResponse(
            statusCode: 500,
            body: {'success': false, 'message': 'Atama bilgileri alınamadı.'},
          );
        }
        return FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [refreshedAssignment],
            },
          },
        );
      },
      assignmentHandler: (request) {
        if (request.path.endsWith('/work-sessions')) {
          return workSessions.future;
        }
        if (request.path.endsWith('/disputes')) {
          return const FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': [
                {
                  'id': 'dispute-new',
                  'jobAssignmentId': 'assignment-1',
                  'status': 'OPEN',
                  'reason': 'Yeni uyuşmazlık',
                },
              ],
            },
          );
        }
        return const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        );
      },
      paymentHandler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': [
            {
              'id': 'attempt-new',
              'status': 'IN_REVIEW',
              'currency': 'TRY',
              'workerPayout': '1000.10',
              'commissionAmount': '50.01',
              'commissionRate': '0.050',
              'totalCharged': '1050.11',
              'createdAt': '2026-09-09T12:00:00Z',
            },
          ],
        },
      ),
    );

    expect(find.text('Atama bilgileri alınamadı.'), findsOneWidget);
    final retry = find.byKey(const ValueKey('retry-assignment-load'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Devam Ediyor'), findsNothing);
    expect(find.text('Yeni uyuşmazlık'), findsNothing);
    expect(find.text('İnceleniyor'), findsNothing);
    expect(find.text('45dk'), findsNothing);

    workSessions.complete(
      const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': [
            {
              'id': 'session-new',
              'jobAssignmentId': 'assignment-1',
              'checkInAt': '2026-09-09T09:00:00Z',
              'checkOutAt': '2026-09-09T09:45:00Z',
              'minutes': 45,
            },
          ],
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atama bilgileri alınamadı.'), findsNothing);
    expect(find.text('Devam Ediyor'), findsOneWidget);
    expect(find.text('Yeni uyuşmazlık'), findsOneWidget);
    expect(find.text('İnceleniyor'), findsOneWidget);
    expect(find.text('45dk'), findsWidgets);
  });

  testWidgets('geç kalan eski yenileme yeni güvenilir durumu bozamaz', (
    tester,
  ) async {
    var assignmentFetchCount = 0;
    final lateFailure = Completer<FakeApiResponse>();
    final refreshedAssignment = <String, Object?>{
      ...assignmentJson,
      'status': 'IN_PROGRESS',
      'paymentStatus': 'HELD_IN_ESCROW',
    };
    final harness = await pumpPage(
      tester,
      employerHandler: (_) {
        assignmentFetchCount++;
        if (assignmentFetchCount == 2) return lateFailure.future;
        return FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                assignmentFetchCount == 1
                    ? assignmentJson
                    : refreshedAssignment,
              ],
            },
          },
        );
      },
    );

    expect(find.text('Onaylandı'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var index = 0; index < 20; index++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(harness.employerApi.requests, hasLength(2));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Devam Ediyor'), findsOneWidget);
    lateFailure.complete(
      const FakeApiResponse(
        statusCode: 500,
        body: {'success': false, 'message': 'Geç kalan atama hatası.'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Devam Ediyor'), findsOneWidget);
    expect(find.text('Geç kalan atama hatası.'), findsNothing);
    expect(find.byKey(const ValueKey('assignment-load-error')), findsNothing);
  });

  testWidgets(
    'ilk mesai yükleme hatasını görünür ve tekrar denenebilir gösterir',
    (tester) async {
      var workSessionFetchCount = 0;
      await pumpPage(
        tester,
        assignmentHandler: (request) {
          if (request.path.endsWith('/work-sessions')) {
            workSessionFetchCount++;
            if (workSessionFetchCount == 1) {
              return const FakeApiResponse(
                statusCode: 500,
                body: {
                  'success': false,
                  'message': 'Mesai kayıtları alınamadı.',
                },
              );
            }
          }
          return const FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': []},
          );
        },
      );

      expect(find.text('Mesai kayıtları alınamadı.'), findsOneWidget);
      expect(find.text('Çalışan henüz mesai başlatmadı.'), findsNothing);
      expect(
        find.byKey(const ValueKey('retry-assignment-load')),
        findsOneWidget,
      );
      expect(find.text('Güvenli Ödemeyi Tamamla'), findsNothing);
      expect(find.text('İşi Tamamla'), findsNothing);
      expect(find.text('İşi İptal Et'), findsNothing);

      final retry = find.byKey(const ValueKey('retry-assignment-load'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(find.text('Mesai kayıtları alınamadı.'), findsNothing);
      expect(find.text('Çalışan henüz mesai başlatmadı.'), findsOneWidget);
    },
  );

  testWidgets(
    'mesai yenileme hatasında güvenilir listeyi koruyup eylemleri kapatır',
    (tester) async {
      var workSessionFetchCount = 0;
      await pumpPage(
        tester,
        assignmentHandler: (request) {
          if (request.path.endsWith('/work-sessions')) {
            workSessionFetchCount++;
            if (workSessionFetchCount > 1) {
              return const FakeApiResponse(
                statusCode: 500,
                body: {
                  'success': false,
                  'message': 'Mesai kayıtları güncellenemedi.',
                },
              );
            }
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': [
                  {
                    'id': 'session-1',
                    'jobAssignmentId': 'assignment-1',
                    'checkInAt': '2026-09-09T09:00:00Z',
                    'checkOutAt': '2026-09-09T09:45:00Z',
                    'minutes': 45,
                  },
                ],
              },
            );
          }
          return const FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': []},
          );
        },
      );

      expect(find.text('45dk'), findsWidgets);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('45dk'), findsWidgets);
      expect(find.text('Mesai kayıtları güncellenemedi.'), findsOneWidget);
      expect(find.text('Çalışan henüz mesai başlatmadı.'), findsNothing);
      expect(
        find.byKey(const ValueKey('retry-assignment-load')),
        findsOneWidget,
      );
      expect(find.text('Güvenli Ödemeyi Tamamla'), findsNothing);
      expect(find.text('İşi Tamamla'), findsNothing);
      expect(find.text('İşi İptal Et'), findsNothing);
    },
  );

  testWidgets('bekleyen çalışan seçimi yaşam döngüsü yenilemesinde korunur', (
    tester,
  ) async {
    final first = <String, Object?>{
      ...assignmentJson,
      'worker': {'id': 'worker-1', 'firstName': 'Ayşe', 'lastName': 'Çalışan'},
    };
    final second = <String, Object?>{
      ...assignmentJson,
      'id': 'assignment-2',
      'worker': {'id': 'worker-2', 'firstName': 'Bora', 'lastName': 'Çalışan'},
    };
    var assignmentFetchCount = 0;
    final pendingSelection = Completer<FakeApiResponse>();
    final harness = await pumpPage(
      tester,
      employerHandler: (_) {
        assignmentFetchCount++;
        if (assignmentFetchCount == 2) return pendingSelection.future;
        return FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [first, second],
            },
          },
        );
      },
    );

    final selector = find.byKey(const ValueKey('assignment-selector'));
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bora Çalışan').last);
    await tester.pump();
    for (var index = 0; index < 20; index++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(harness.employerApi.requests, hasLength(2));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      tester.widget<DropdownButton<String>>(selector).value,
      'assignment-2',
    );
    expect(
      harness.paymentApi.requests.where(
        (request) => request.path == '/job-assignments/assignment-2/payments',
      ),
      hasLength(1),
    );

    pendingSelection.complete(
      FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {
            'content': [first, second],
          },
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<DropdownButton<String>>(selector).value,
      'assignment-2',
    );
  });

  testWidgets(
    'mevcut çalışanın mesai hatası sağlıklı çalışan seçimini kapatmaz',
    (tester) async {
      final first = <String, Object?>{
        ...assignmentJson,
        'worker': {
          'id': 'worker-1',
          'firstName': 'Ayşe',
          'lastName': 'Çalışan',
        },
      };
      final second = <String, Object?>{
        ...assignmentJson,
        'id': 'assignment-2',
        'worker': {
          'id': 'worker-2',
          'firstName': 'Bora',
          'lastName': 'Çalışan',
        },
      };
      final harness = await pumpPage(
        tester,
        assignments: [first, second],
        assignmentHandler: (request) {
          if (request.path == '/job-assignments/assignment-1/work-sessions') {
            return const FakeApiResponse(
              statusCode: 500,
              body: {'success': false, 'message': 'Ayşe için mesai alınamadı.'},
            );
          }
          return const FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': []},
          );
        },
      );

      expect(find.text('Ayşe için mesai alınamadı.'), findsOneWidget);
      final selector = find.byKey(const ValueKey('assignment-selector'));
      expect(
        tester.widget<DropdownButton<String>>(selector).onChanged,
        isNotNull,
      );

      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bora Çalışan').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<DropdownButton<String>>(selector).value,
        'assignment-2',
      );
      expect(find.text('Ayşe için mesai alınamadı.'), findsNothing);
      expect(find.text('Güvenli Ödemeyi Tamamla'), findsOneWidget);
      expect(
        harness.paymentApi.requests.where(
          (request) => request.path == '/job-assignments/assignment-2/payments',
        ),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'tamamlama onayı açıkken değişen mesai eski onayı geçersiz kılar',
    (tester) async {
      var workSessionFetchCount = 0;
      final harness = await pumpPage(
        tester,
        employerHandler: (request) {
          if (request.method == 'POST') {
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {...assignmentJson, 'status': 'COMPLETED'},
              },
            );
          }
          return assignmentPage(assignmentJson);
        },
        assignmentHandler: (request) {
          if (request.path.endsWith('/work-sessions')) {
            workSessionFetchCount++;
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': workSessionFetchCount == 1
                    ? const []
                    : const [
                        {
                          'id': 'session-open',
                          'jobAssignmentId': 'assignment-1',
                          'checkInAt': '2026-09-09T09:00:00Z',
                        },
                      ],
              },
            );
          }
          return const FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': []},
          );
        },
      );

      final button = find.text('İşi Tamamla');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('İşi tamamla'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tamamla'));
      await tester.pumpAndSettle();

      expect(
        harness.employerApi.requests.where(
          (request) =>
              request.method == 'POST' && request.path.endsWith('/complete'),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'iptal kutusu açıkken değişen yaşam döngüsü eski onayı geçersiz kılar',
    (tester) async {
      var assignmentFetchCount = 0;
      final harness = await pumpPage(
        tester,
        employerHandler: (_) {
          assignmentFetchCount++;
          return assignmentPage(
            assignmentFetchCount == 1
                ? assignmentJson
                : <String, Object?>{...assignmentJson, 'status': 'COMPLETED'},
          );
        },
        assignmentHandler: (request) {
          if (request.path.endsWith('/cancellation-preview')) {
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {'cancellableNow': true},
              },
            );
          }
          if (request.method == 'POST') {
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'id': 'cancellation-1',
                  'jobAssignmentId': 'assignment-1',
                  'cancelledByParty': 'EMPLOYER',
                },
              },
            );
          }
          return const FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': []},
          );
        },
      );

      final button = find.text('İşi İptal Et');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Plan değişti');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.text('İptal Et'));
      await tester.pumpAndSettle();

      expect(
        harness.assignmentApi.requests.where(
          (request) => request.method == 'POST',
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'sorun kutusu açıkken açılan uyuşmazlık eski onayı geçersiz kılar',
    (tester) async {
      var disputeFetchCount = 0;
      final heldAssignment = <String, Object?>{
        ...assignmentJson,
        'status': 'IN_PROGRESS',
        'paymentStatus': 'HELD_IN_ESCROW',
      };
      final harness = await pumpPage(
        tester,
        assignments: [heldAssignment],
        assignmentHandler: (request) {
          if (request.path.endsWith('/disputes')) {
            disputeFetchCount++;
            return FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': disputeFetchCount == 1
                    ? const []
                    : const [
                        {
                          'id': 'dispute-open',
                          'jobAssignmentId': 'assignment-1',
                          'status': 'OPEN',
                          'reason': 'Başka uyuşmazlık',
                        },
                      ],
              },
            );
          }
          if (request.method == 'POST') {
            return const FakeApiResponse(
              statusCode: 200,
              body: {
                'success': true,
                'data': {
                  'id': 'dispute-new',
                  'jobAssignmentId': 'assignment-1',
                  'status': 'OPEN',
                },
              },
            );
          }
          return const FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': []},
          );
        },
      );

      final button = find.text('Sorun Bildir');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ücret uyuşmazlığı');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bildir'));
      await tester.pumpAndSettle();

      expect(
        harness.assignmentApi.requests.where(
          (request) => request.method == 'POST',
        ),
        isEmpty,
      );
    },
  );

  testWidgets('açık uyuşmazlık tamamlama ve iptali birlikte dondurur', (
    tester,
  ) async {
    await pumpPage(tester, openDispute: true);

    expect(find.textContaining('Emanetteki ücret'), findsOneWidget);
    expect(find.text('İşi Tamamla'), findsNothing);
    expect(find.text('İşi İptal Et'), findsNothing);
  });

  testWidgets('uyuşmazlık durumu alınamazsa finansal eylemler kapalı kalır', (
    tester,
  ) async {
    await pumpPage(tester, disputeStatusCode: 500);

    expect(find.text('Uyuşmazlık durumu doğrulanamadı.'), findsOneWidget);
    expect(find.text('İşi Tamamla'), findsNothing);
    expect(find.text('İşi İptal Et'), findsNothing);
    expect(find.text('Sorun Bildir'), findsNothing);
  });

  testWidgets('uyuşmazlık kontrolü sürerken finansal eylemler kapalı kalır', (
    tester,
  ) async {
    final response = Completer<FakeApiResponse>();
    await pumpPage(tester, disputeResponse: response, settle: false);

    expect(find.text('Atama bilgileri güncelleniyor.'), findsOneWidget);
    expect(find.text('İşi Tamamla'), findsNothing);
    expect(find.text('İşi İptal Et'), findsNothing);

    response.complete(
      const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': []},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atama bilgileri güncelleniyor.'), findsNothing);
    expect(find.text('İşi Tamamla'), findsOneWidget);
    expect(find.text('İşi İptal Et'), findsOneWidget);
  });

  testWidgets('çoklu ilanda çalışan açıkça seçilir ve ödeme hedefi değişir', (
    tester,
  ) async {
    final first = <String, Object?>{
      ...assignmentJson,
      'worker': {'id': 'worker-1', 'firstName': 'Ayşe', 'lastName': 'Çalışan'},
    };
    final second = <String, Object?>{
      ...assignmentJson,
      'id': 'assignment-2',
      'worker': {'id': 'worker-2', 'firstName': 'Bora', 'lastName': 'Çalışan'},
    };
    final harness = await pumpPage(tester, assignments: [first, second]);

    final selector = find.byKey(const ValueKey('assignment-selector'));
    expect(selector, findsOneWidget);
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bora Çalışan').last);
    await tester.pumpAndSettle();

    expect(
      harness.paymentApi.requests.any(
        (request) => request.path == '/job-assignments/assignment-2/payments',
      ),
      isTrue,
    );
  });
}
