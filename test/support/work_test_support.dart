import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/models/timesheet_event.dart';
import 'package:koala/employee/features/jobs/models/work_session.dart';
import 'package:koala/employee/features/jobs/presentation/providers/timesheet_queue_provider.dart';
import 'package:koala/employee/features/jobs/services/timesheet_event_gateway.dart';
import 'package:koala/employee/features/jobs/services/timesheet_event_store.dart';
import 'package:koala/employee/features/jobs/services/timesheet_retry_trigger.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';

import 'fake_api.dart';

/// İşlerim ve iş detayı testlerinin ortak parçaları.
///
/// İki sayfa aynı kaydı — bir atama ya da başvuru — farklı yerlerden
/// çiziyor; gövdeler, çalışan oturumu ve çevrimdışı mesai kuyruğu bir yerde
/// dursun ki bir alan adı değiştiğinde iki test aynı anda kırılsın.

/// Testlerdeki çalışanın kimliği.
const String workerId = 'worker-1';

/// İlan özeti (`JobSummaryDto`); bireysel ilan varsayılan.
Map<String, Object?> jobSummaryJson({
  String id = 'job-1',
  String title = 'Barista',
  String employerType = 'INDIVIDUAL',
  String? companyName,
  String? companyId,
  String? companyLogoUrl,
}) => {
  'id': id,
  'title': title,
  'category': {'id': 'category-1', 'code': 'BARISTA', 'name': 'Barista'},
  'type': 'ONE_TIME',
  'employerType': employerType,
  'salaryType': 'DAILY',
  'salary': 1000,
  'status': 'OPEN',
  'startDateTime': '2026-09-10T09:00:00Z',
  'endDateTime': '2026-09-10T17:00:00Z',
  'cityName': 'İstanbul',
  'districtName': 'Kadıköy',
  'companyName': ?companyName,
  'companyId': ?companyId,
  'companyLogoUrl': ?companyLogoUrl,
};

/// Atama (`MyAssignmentDto`). Kapı ve çizelge alanları isteğe bağlı ki eski
/// sunucu (alan yok) da denenebilsin.
Map<String, Object?> assignmentJson({
  String id = 'assignment-1',
  String status = 'CONFIRMED',
  String paymentStatus = 'HELD_IN_ESCROW',
  String? assignmentDateTime = '2026-09-08T12:00:00Z',
  String? actualCompletionDateTime,
  bool? messagingAvailable,
  String? messagingAvailableReason,
  Map<String, Object?>? job,
  Map<String, Object?> extra = const {},
}) => {
  'id': id,
  'status': status,
  'paymentStatus': paymentStatus,
  'assignmentDateTime': ?assignmentDateTime,
  'actualCompletionDateTime': ?actualCompletionDateTime,
  'workerPayout': 950,
  'pricing': {
    'pricingVersion': 'v1',
    'currency': 'TRY',
    'workerPayout': '950.00',
    'serviceFeeRate': '0.05',
    'serviceFeeAmount': '50.00',
    'employerTotal': '1000.00',
  },
  'job': job ?? jobSummaryJson(),
  'messagingAvailable': ?messagingAvailable,
  'messagingAvailableReason': ?messagingAvailableReason,
  ...extra,
};

/// koala-backend#282'nin atamaya eklediği alanlar; testler bunları
/// [assignmentJson]'ın `extra`'sına veriyor.
const Map<String, Object?> timelineFieldsJson = {
  'createdAt': '2026-09-02T08:00:00Z',
  'confirmedAt': '2026-09-02T09:30:00Z',
  'paymentSecuredAt': '2026-09-03T12:00:00Z',
  'application': {
    'id': 'application-1',
    'applicationDateTime': '2026-09-01T10:00:00Z',
    'answeredDateTime': '2026-09-02T08:00:00Z',
  },
  'payout': {
    'id': 'payout-1',
    'status': 'COMPLETED',
    'completedAt': '2026-09-11T09:00:00Z',
  },
};

/// Başvuru (`MyApplicationDto`).
Map<String, Object?> applicationJson({
  String id = 'application-1',
  String status = 'APPLIED',
  String? answeredDateTime,
  String? rejectionReason,
  Map<String, Object?>? job,
}) => {
  'id': id,
  'status': status,
  'applicationDateTime': '2026-09-01T10:00:00Z',
  'answeredDateTime': ?answeredDateTime,
  'rejectionReason': ?rejectionReason,
  'job': job ?? jobSummaryJson(id: 'job-2', title: 'Garson'),
};

/// Mesai oturumu (`WorkSessionDto`).
Map<String, Object?> workSessionJson({
  String id = 'session-1',
  String assignmentId = 'assignment-1',
  String checkInAt = '2026-09-10T09:05:00Z',
  String? checkOutAt = '2026-09-10T16:50:00Z',
  int? minutes = 465,
}) => {
  'id': id,
  'jobAssignmentId': assignmentId,
  'checkInAt': checkInAt,
  'checkOutAt': ?checkOutAt,
  'minutes': ?minutes,
};

/// Sayfalı liste yanıtı.
FakeApiResponse pageResponse(List<Map<String, Object?>> content) =>
    FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {'content': content},
      },
    );

/// `data` olarak verilen gövdeyi taşıyan başarılı yanıt.
FakeApiResponse dataResponse(Object? data) =>
    FakeApiResponse(statusCode: 200, body: {'success': true, 'data': data});

/// `/users/me`'den dönmüş, yüklü bir çalışan.
Future<UserProvider> loadedWorkerProvider() async {
  final api = FakeApi(
    handler: (_) => dataResponse({
      'id': workerId,
      'firstName': 'Yakup',
      'lastName': 'Kahraman',
      'email': 'yakup@example.com',
      'isEmployer': false,
    }),
  );
  final provider = UserProvider(
    userService: UserService.withClient(api.client),
  );
  await provider.load();
  return provider;
}

/// Ağa çıkmayan, bellekte tutulan mesai kuyruğu.
///
/// Sayfalar kuyruğu `initState`'te başlatıyor; gerçek `sqflite` deposu ve
/// bağlantı tetikleyicisi testte yok. Dönen kuyruk testin sonunda kendini
/// kapatıyor.
TimesheetQueueProvider idleTimesheetQueue() {
  final retryTrigger = _ManualRetryTrigger();
  final queue = TimesheetQueueProvider.withAdapters(
    store: _MemoryStore(),
    gateway: _IdleGateway(),
    retryTrigger: retryTrigger,
  );
  addTearDown(() => retryTrigger.controller.close());
  return queue;
}

/// `/work-detail` rotasının yerine geçen sahte sayfa.
///
/// Gerçek `WorkDetailPage` kendi servislerini kuruyor ve ağa çıkıyor;
/// satırın detayı **açıp açmadığını** ve hangi kaydı geçirdiğini ölçmek
/// için sözleşmesi yetiyor: `extra` olarak bir [MyJob] alır. Açılan kayıt
/// [onOpened] ile dışarı veriliyor.
GoRoute stubWorkDetailRoute({void Function(MyJob job)? onOpened}) {
  return GoRoute(
    path: '/work-detail',
    pageBuilder: (context, state) {
      final job = state.extra as MyJob;
      onOpened?.call(job);
      return MaterialPage<void>(
        key: state.pageKey,
        child: Scaffold(
          appBar: AppBar(title: const Text(workDetailStubTitle)),
          body: Center(child: Text(job.title)),
        ),
      );
    },
  );
}

/// Sahte iş detayının başlığı; "detay açıldı" iddiası buna bakıyor.
const String workDetailStubTitle = 'İş detayı ekranı';

class _MemoryStore implements TimesheetEventStore {
  final List<TimesheetEvent> records = [];
  String? lastActiveUserId;

  @override
  Future<void> add(TimesheetEvent event) async => records.add(event);

  @override
  Future<List<TimesheetEvent>> readForUser(String userId) async =>
      records.where((event) => event.userId == userId).toList(growable: false);

  @override
  Future<void> remove(String clientEventId) async {
    records.removeWhere((event) => event.clientEventId == clientEventId);
  }

  @override
  Future<void> markRequiresSupport(
    String clientEventId,
    String message,
  ) async {}

  @override
  Future<String?> readLastActiveUser() async => lastActiveUserId;

  @override
  Future<void> setLastActiveUser(String? userId) async {
    lastActiveUserId = userId;
  }
}

class _IdleGateway implements TimesheetEventGateway {
  @override
  Future<WorkSession> send(TimesheetEvent event) =>
      throw UnimplementedError('Bu testte mesai gönderilmiyor.');

  @override
  Future<List<WorkSession>> fetchSessions(String assignmentId) async => [];
}

class _ManualRetryTrigger implements TimesheetRetryTrigger {
  final StreamController<void> controller = StreamController<void>.broadcast();

  @override
  Stream<void> get onNetworkAvailable => controller.stream;
}
