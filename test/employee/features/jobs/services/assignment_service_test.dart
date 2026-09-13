import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('AssignmentService.fetchMyAssignments', () {
    test('sayfalı yanıt modele çevrilir', () async {
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
                  'workerPayout': 1350,
                  'job': {
                    'id': 'job_1',
                    'title': 'Garson',
                    'category': {
                      'id': 'c',
                      'code': 'WAITER',
                      'name': 'Garsonluk',
                    },
                    'salary': 1500,
                  },
                },
              ],
              'totalElements': 1,
              'last': true,
            },
          },
        ),
      );

      final page = await AssignmentService.withClient(
        api.client,
      ).fetchMyAssignments();

      expect(api.requests.single.path, '/users/me/assignments');
      expect(api.requests.single.queryParameters, {'page': 0, 'size': 20});
      expect(page.assignments.single.workerPayout, 1350);
    });

    test('boş sayfa hata değil', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'content': []},
          },
        ),
      );

      final page = await AssignmentService.withClient(
        api.client,
      ).fetchMyAssignments();

      expect(page.assignments, isEmpty);
    });
  });

  group('AssignmentService.respond', () {
    test('kabul cevabı doğru yola ve gövdeyle gider', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'id': 'asg_1', 'status': 'CONFIRMED'},
          },
        ),
      );

      final status = await AssignmentService.withClient(
        api.client,
      ).respond(assignmentId: 'asg_1', accepted: true);

      final request = api.requests.single;
      expect(request.path, '/job-assignments/asg_1/respond');
      expect(request.method, 'POST');
      expect(request.data, {'accepted': true});
      expect(status, AssignmentStatus.confirmed);
    });

    test('ret cevabı REJECTED döndürür', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'id': 'asg_1', 'status': 'REJECTED'},
          },
        ),
      );

      final status = await AssignmentService.withClient(
        api.client,
      ).respond(assignmentId: 'asg_1', accepted: false);

      expect(api.requests.single.data, {'accepted': false});
      expect(status, AssignmentStatus.rejected);
    });

    test('atama cevaplanabilir durumda değilse 409 yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {'success': false, 'message': 'Atama bu durumdan cevaplanamaz'},
        ),
      );

      await expectLater(
        AssignmentService.withClient(
          api.client,
        ).respond(assignmentId: 'asg_1', accepted: true),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.dataConflict,
          ),
        ),
      );
    });
  });

  group('AssignmentService mesai', () {
    FakeApi sessionApi({int statusCode = 201, String? checkOutAt}) {
      return FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: statusCode,
          body: {
            'success': true,
            'data': {
              'id': 'ws_1',
              'jobAssignmentId': 'asg_1',
              'checkInAt': '2026-03-10T09:30:00Z',
              'checkOutAt': checkOutAt,
            },
          },
        ),
      );
    }

    test('giriş konumla gönderilir', () async {
      final api = sessionApi();

      final session = await AssignmentService.withClient(
        api.client,
      ).checkIn(assignmentId: 'asg_1', latitude: 39.92, longitude: 32.85);

      final request = api.requests.single;
      expect(request.path, '/job-assignments/asg_1/check-in');
      expect(request.data, {'latitude': 39.92, 'longitude': 32.85});
      expect(session.isOpen, isTrue);
    });

    test('giriş konumu altı ondalığa yuvarlanarak gönderilir', () async {
      final api = sessionApi();

      await AssignmentService.withClient(api.client).checkIn(
        assignmentId: 'asg_1',
        latitude: 41.01234567891,
        longitude: 28.97654321098,
      );

      expect(api.requests.single.data, {
        'latitude': 41.012346,
        'longitude': 28.976543,
      });
    });

    test(
      'çevrimdışı olay kimliği ve yakalanma anı birlikte gönderilir',
      () async {
        final api = sessionApi();
        final capturedAt = DateTime.parse('2026-09-06T10:00:00Z');

        await AssignmentService.withClient(api.client).checkIn(
          assignmentId: 'asg_1',
          latitude: 39.92,
          longitude: 32.85,
          clientEventId: '3d513c3e-e449-4e0a-ae0-ef3cdef809e4',
          capturedAt: capturedAt,
        );

        expect(api.requests.single.data, {
          'latitude': 39.92,
          'longitude': 32.85,
          'clientEventId': '3d513c3e-e449-4e0a-ae0-ef3cdef809e4',
          'capturedAt': '2026-09-06T10:00:00.000Z',
        });
      },
    );

    test('olay kimliği yakalanma anı olmadan gönderilemez', () {
      final api = sessionApi();

      expect(
        () => AssignmentService.withClient(
          api.client,
        ).checkIn(assignmentId: 'asg_1', clientEventId: 'event-without-time'),
        throwsArgumentError,
      );
      expect(api.requests, isEmpty);
    });

    // Konum isteğe bağlı: alınamadığında giriş yine yapılabilmeli, gövdede
    // boş koordinat gönderilmemeli.
    test('konum alınamazsa gövde boş gider', () async {
      final api = sessionApi();

      await AssignmentService.withClient(
        api.client,
      ).checkIn(assignmentId: 'asg_1');

      expect(api.requests.single.data, isEmpty);
    });

    test('çıkış doğru yola gider', () async {
      final api = sessionApi(
        statusCode: 200,
        checkOutAt: '2026-03-10T17:30:00Z',
      );

      final session = await AssignmentService.withClient(
        api.client,
      ).checkOut(assignmentId: 'asg_1');

      expect(api.requests.single.path, '/job-assignments/asg_1/check-out');
      expect(session.isOpen, isFalse);
    });

    // Para emanete geçmeden giriş yapılamıyor; mesajı sunucu veriyor.
    test('ödeme güvenceye alınmadan giriş 409 yükseltir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {'success': false, 'message': 'Ücret henüz güvenceye alınmadı'},
        ),
      );

      await expectLater(
        AssignmentService.withClient(api.client).checkIn(assignmentId: 'asg_1'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.dataConflict,
          ),
        ),
      );
    });

    test('oturum listesi düz dizi olarak ayrıştırılır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {
                'id': 'ws_1',
                'jobAssignmentId': 'asg_1',
                'checkInAt': '2026-03-10T09:30:00Z',
                'checkOutAt': '2026-03-10T17:30:00Z',
                'minutes': 480,
              },
            ],
          },
        ),
      );

      final sessions = await AssignmentService.withClient(
        api.client,
      ).fetchWorkSessions('asg_1');

      expect(api.requests.single.path, '/job-assignments/asg_1/work-sessions');
      expect(sessions.single.minutes, 480);
    });

    test('oturumu olmayan atamada boş liste', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        ),
      );

      final sessions = await AssignmentService.withClient(
        api.client,
      ).fetchWorkSessions('asg_1');

      expect(sessions, isEmpty);
    });
  });

  group('AssignmentService iptal ve uyuşmazlık', () {
    test('iptal gerekçeyle doğru yola gider', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': {
              'id': 'cnc_1',
              'jobAssignmentId': 'asg_1',
              'cancelledByParty': 'WORKER',
              'feeRate': '0',
              'feeAmount': '0.00',
              'refundAmount': '1500.00',
            },
          },
        ),
      );

      final cancellation = await AssignmentService.withClient(
        api.client,
      ).cancel(assignmentId: 'asg_1', reason: 'Hastalandım');

      final request = api.requests.single;
      expect(request.path, '/job-assignments/asg_1/cancel');
      expect(request.data, {'reason': 'Hastalandım'});
      expect(cancellation.hasFee, isFalse);
    });

    test('ikinci iptal 409 yükseltir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {'success': false, 'message': 'Bu iş zaten iptal edilmiş'},
        ),
      );

      await expectLater(
        AssignmentService.withClient(
          api.client,
        ).cancel(assignmentId: 'asg_1', reason: 'Gerekçe'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.dataConflict,
          ),
        ),
      );
    });

    // İptal edilmemiş atamada uç `data: null` döndürüyor.
    test('iptal kaydı yoksa null döner', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': null},
        ),
      );

      final cancellation = await AssignmentService.withClient(
        api.client,
      ).fetchCancellation('asg_1');

      expect(api.requests.single.path, '/job-assignments/asg_1/cancellation');
      expect(cancellation, isNull);
    });

    test('uyuşmazlık gerekçeyle açılır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 201,
          body: {
            'success': true,
            'data': {
              'id': 'dsp_1',
              'jobAssignmentId': 'asg_1',
              'status': 'OPEN',
              'reason': 'İş tarif edildiği gibi değildi',
            },
          },
        ),
      );

      final dispute = await AssignmentService.withClient(api.client)
          .openDispute(
            assignmentId: 'asg_1',
            reason: 'İş tarif edildiği gibi değildi',
          );

      final request = api.requests.single;
      expect(request.path, '/job-assignments/asg_1/disputes');
      expect(request.method, 'POST');
      expect(dispute.isOpen, isTrue);
    });

    // Emanette para yoksa ya da zaten açık bir uyuşmazlık varsa.
    test('uyuşmazlık açılamadığında 409 yükselir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 409,
          body: {'success': false, 'message': 'Emanette para yok'},
        ),
      );

      await expectLater(
        AssignmentService.withClient(
          api.client,
        ).openDispute(assignmentId: 'asg_1', reason: 'Sorun'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.dataConflict,
          ),
        ),
      );
    });

    test('uyuşmazlık listesi düz dizi olarak ayrıştırılır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {
                'id': 'dsp_1',
                'jobAssignmentId': 'asg_1',
                'status': 'RESOLVED',
                'resolution': 'RELEASE_TO_WORKER',
              },
            ],
          },
        ),
      );

      final disputes = await AssignmentService.withClient(
        api.client,
      ).fetchDisputes('asg_1');

      expect(api.requests.single.method, 'GET');
      expect(disputes.single.isOpen, isFalse);
    });

    test('uyuşmazlığı olmayan atamada boş liste', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        ),
      );

      final disputes = await AssignmentService.withClient(
        api.client,
      ).fetchDisputes('asg_1');

      expect(disputes, isEmpty);
    });
  });

  group('AssignmentService.fetchCancellationPreview', () {
    test('önizleme doğru yola gider ve modele çevrilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'feeRate': '0.5',
              'feeAmount': '750.00',
              'refundAmount': '750.00',
              'noticeMinutes': 300,
              'cancellableNow': true,
            },
          },
        ),
      );

      final preview = await AssignmentService.withClient(
        api.client,
      ).fetchCancellationPreview('asg_1');

      final request = api.requests.single;
      expect(request.path, '/job-assignments/asg_1/cancellation-preview');
      expect(request.method, 'GET');
      expect(preview.feePercent, 50);
      expect(preview.cancellableNow, isTrue);
    });

    // Uygun olmayan durumda sunucu hata atmıyor; bayrak dönüyor.
    test('iptal edilemeyen atamada hata değil bayrak döner', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {'cancellableNow': false},
          },
        ),
      );

      final preview = await AssignmentService.withClient(
        api.client,
      ).fetchCancellationPreview('asg_1');

      expect(preview.cancellableNow, isFalse);
    });

    test('atamanın tarafı olmayan 404 alır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {'success': false, 'message': 'Atama bulunamadı'},
        ),
      );

      await expectLater(
        AssignmentService.withClient(
          api.client,
        ).fetchCancellationPreview('asg_1'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.type,
            'type',
            ApiErrorType.notFound,
          ),
        ),
      );
    });
  });
}
