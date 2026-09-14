import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/cancellation.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/models/payout.dart';

Map<String, dynamic> assignmentBody({
  String status = 'CONFIRMED',
  String paymentStatus = 'HELD_IN_ESCROW',
  num? workerPayout = 1350,
  Map<String, dynamic>? pricing = const {
    'pricingVersion': 'v7',
    'currency': 'TRY',
    'workerPayout': '1350.00',
    'serviceFeeRate': '0.075',
    'serviceFeeAmount': '101.25',
    'employerTotal': '1451.25',
  },
  bool? messagingAvailable,
  String? messagingAvailableReason,
}) {
  return {
    'id': 'asg_1',
    'status': status,
    'paymentStatus': paymentStatus,
    'assignmentDateTime': '2026-03-10T09:00:00Z',
    'workHours': 6,
    'workerPayout': workerPayout,
    'totalCharged': 1500,
    'pricing': pricing,
    'messagingAvailable': ?messagingAvailable,
    'messagingAvailableReason': ?messagingAvailableReason,
    'job': {
      'id': 'job_1',
      'title': 'Düğün Fotoğrafçısı',
      'position': 'Fotoğrafçı',
      'category': {'id': 'c', 'code': 'PHOTOGRAPHY', 'name': 'Fotoğrafçılık'},
      'salary': 1500,
      'companyName': 'Koala Organizasyon',
    },
  };
}

void main() {
  group('Assignment', () {
    test('sunucu gövdesi modele çevrilir', () {
      final assignment = Assignment.fromJson(assignmentBody());

      expect(assignment.status, AssignmentStatus.confirmed);
      expect(assignment.paymentStatus, PaymentStatus.heldInEscrow);
      expect(assignment.workHours, 6);
      expect(assignment.workerPayout, 1350);
      expect(assignment.pricing?.pricingVersion, 'v7');
      expect(assignment.pricing?.workerPayout, '1350.00');
      expect(assignment.pricing?.employerTotal, '1451.25');
      expect(assignment.job.title, 'Düğün Fotoğrafçısı');
    });

    test('pricing snapshot ondalıkları yalnız string kabul eder', () {
      expect(
        () => Assignment.fromJson(
          assignmentBody(
            pricing: {
              'pricingVersion': 'v7',
              'currency': 'TRY',
              'workerPayout': 1350.00,
              'serviceFeeRate': '0.075',
              'serviceFeeAmount': '101.25',
              'employerTotal': '1451.25',
            },
          ),
        ),
        throwsFormatException,
      );
    });

    // Çalışanın eline geçen tutar komisyon düşülmüş hâli; ilandaki ücretten
    // farklı olduğu için ayrı taşınıyor.
    test('çalışan kazancı ilan ücretinden ayrı', () {
      final assignment = Assignment.fromJson(assignmentBody());

      expect(assignment.workerPayout, isNot(assignment.job.price));
      expect(assignment.totalCharged, 1500);
    });

    test('ödeme çalışana geçmeden isPaidOut false', () {
      final assignment = Assignment.fromJson(
        assignmentBody(status: 'COMPLETED', paymentStatus: 'HELD_IN_ESCROW'),
      );

      expect(assignment.isPaidOut, isFalse);
    });

    test('iş bitip ödeme serbest bırakılınca isPaidOut true', () {
      final assignment = Assignment.fromJson(
        assignmentBody(
          status: 'COMPLETED',
          paymentStatus: 'RELEASED_TO_WORKER',
        ),
      );

      expect(assignment.isPaidOut, isTrue);
    });

    test('işveren yalnız onaylanmış ve tahsil edilmemiş atamada öder', () {
      expect(
        Assignment.fromJson(
          assignmentBody(paymentStatus: 'PENDING_COLLECTION'),
        ).needsEmployerPayment,
        isTrue,
      );
      expect(
        Assignment.fromJson(
          assignmentBody(paymentStatus: 'FAILED'),
        ).needsEmployerPayment,
        isTrue,
      );
      expect(
        Assignment.fromJson(assignmentBody()).needsEmployerPayment,
        isFalse,
      );
      expect(
        Assignment.fromJson(
          assignmentBody(
            status: 'PENDING_CONFIRMATION',
            paymentStatus: 'PENDING_COLLECTION',
          ),
        ).needsEmployerPayment,
        isFalse,
      );
    });

    test('tanınmayan durumlar varsayılana düşer', () {
      final assignment = Assignment.fromJson(
        assignmentBody(status: 'UZAYLI', paymentStatus: 'UZAYLI'),
      );

      expect(assignment.status, AssignmentStatus.confirmed);
      expect(assignment.paymentStatus, PaymentStatus.pendingCollection);
    });

    test('kazanç gelmezse null kalır', () {
      final assignment = Assignment.fromJson(
        assignmentBody(workerPayout: null),
      );

      expect(assignment.workerPayout, isNull);
    });

    // Mesajlaşma kapısı sunucunun iki alanından okunuyor; alanlar yoksa
    // (backend PR 261 öncesi sunucu) kapı kapalı sayılmalı ki düğme
    // görünmesin.
    test('mesajlaşma kapısı DTO alanlarından okunur', () {
      expect(
        Assignment.fromJson(
          assignmentBody(
            messagingAvailable: true,
            messagingAvailableReason: 'AVAILABLE',
          ),
        ).messaging.isAvailable,
        isTrue,
      );
      expect(
        Assignment.fromJson(
          assignmentBody(
            paymentStatus: 'PENDING_COLLECTION',
            messagingAvailable: false,
            messagingAvailableReason: 'PAYMENT_REQUIRED',
          ),
        ).messaging.needsPayment,
        isTrue,
      );
      expect(
        Assignment.fromJson(
          assignmentBody(
            status: 'CANCELLED',
            paymentStatus: 'REFUNDED',
            messagingAvailable: false,
            messagingAvailableReason: 'CLOSED',
          ),
        ).messaging.isClosed,
        isTrue,
      );
    });

    // koala-backend#282 henüz gelmemiş sunucu: yeni alanların hiçbiri yok.
    test('çizelge alanları gelmezse hepsi null kalır, gövde çözülür', () {
      final assignment = Assignment.fromJson(assignmentBody());

      expect(assignment.createdAt, isNull);
      expect(assignment.confirmedAt, isNull);
      expect(assignment.expectedCompletionDateTime, isNull);
      expect(assignment.paymentSecuredAt, isNull);
      expect(assignment.application, isNull);
      expect(assignment.employer, isNull);
      expect(assignment.company, isNull);
      expect(assignment.cancellation, isNull);
      expect(assignment.payout, isNull);
    });

    test('çizelge, işveren, şirket, iptal ve hakediş alanları okunur', () {
      final assignment = Assignment.fromJson({
        ...assignmentBody(status: 'CANCELLED', paymentStatus: 'REFUNDED'),
        'createdAt': '2026-03-02T08:00:00Z',
        'confirmedAt': '2026-03-02T09:30:00Z',
        'expectedCompletionDateTime': '2026-03-10T17:00:00Z',
        'paymentSecuredAt': '2026-03-03T12:00:00Z',
        'application': {
          'id': 'app_1',
          'applicationDateTime': '2026-03-01T10:00:00Z',
          'answeredDateTime': '2026-03-02T08:00:00Z',
        },
        'employer': {
          'id': 'user_9',
          'firstName': 'Ayşe',
          'lastName': 'Yılmaz',
          'profilePictureUrl': 'https://cdn.example/ayse.png',
        },
        'company': {
          'id': 'comp_7',
          'name': 'Koala Organizasyon',
          'logoUrl': 'https://cdn.example/logo.png',
        },
        'cancellation': {
          'cancelledByParty': 'EMPLOYER',
          'cancelledAt': '2026-03-05T11:00:00Z',
          'feeRate': '0.25',
          'feeAmount': '375.00',
          'refundAmount': '1125.00',
        },
        'payout': {
          'id': 'payout_1',
          'status': 'COMPLETED',
          'completedAt': '2026-03-11T09:00:00Z',
        },
      });

      expect(assignment.createdAt, DateTime.utc(2026, 3, 2, 8));
      expect(assignment.confirmedAt, DateTime.utc(2026, 3, 2, 9, 30));
      expect(
        assignment.expectedCompletionDateTime,
        DateTime.utc(2026, 3, 10, 17),
      );
      expect(assignment.paymentSecuredAt, DateTime.utc(2026, 3, 3, 12));
      expect(assignment.application?.id, 'app_1');
      expect(
        assignment.application?.applicationDateTime,
        DateTime.utc(2026, 3, 1, 10),
      );
      expect(
        assignment.application?.answeredDateTime,
        DateTime.utc(2026, 3, 2, 8),
      );
      expect(assignment.employer?.fullName, 'Ayşe Yılmaz');
      expect(assignment.company?.id, 'comp_7');
      expect(assignment.company?.logoUrl, 'https://cdn.example/logo.png');
      expect(
        assignment.cancellation?.cancelledByParty,
        CancellationParty.employer,
      );
      expect(assignment.cancellation?.feePercent, 25);
      expect(assignment.cancellation?.hasFee, isTrue);
      expect(assignment.payout?.status, PayoutStatus.completed);
      expect(assignment.payout?.completedAt, DateTime.utc(2026, 3, 11, 9));
    });

    test('eski sunucu alanları göndermezse kapı kapalı', () {
      final assignment = Assignment.fromJson(assignmentBody());

      expect(assignment.messaging.isAvailable, isFalse);
      expect(assignment.messaging.needsPayment, isTrue);
    });

    // Çalışan görünümünde sunucu `pricing` ve `totalCharged`'ı `null`
    // gönderiyor (koala-backend#294); kazanç `workerPayout`'ta kalıyor.
    test('çalışan görünümü: pricing ve totalCharged null, kazanç var', () {
      final assignment = Assignment.fromJson({
        ...assignmentBody(pricing: null),
        'totalCharged': null,
      });

      expect(assignment.pricing, isNull);
      expect(assignment.totalCharged, isNull);
      expect(assignment.workerPayout, 1350);
      expect(MyJob.fromAssignment(assignment).price, 1350);
    });

    group('değerlendirme durumu (koala-backend#293)', () {
      test('myReview dolu ve counterpartyReviewed okunur', () {
        final assignment = Assignment.fromJson({
          ...assignmentBody(status: 'COMPLETED'),
          'myReview': {
            'id': 'rev_mine',
            'rating': 4,
            'comment': 'Çok iyiydi',
            'createdAt': '2026-03-11T10:00:00Z',
          },
          'counterpartyReviewed': true,
        });

        expect(assignment.myReview?.id, 'rev_mine');
        expect(assignment.myReview?.rating, 4);
        expect(assignment.myReview?.comment, 'Çok iyiydi');
        expect(assignment.myReview?.createdAt, DateTime.utc(2026, 3, 11, 10));
        expect(assignment.counterpartyReviewed, isTrue);
      });

      test('myReview null: henüz değerlendirilmemiş', () {
        final assignment = Assignment.fromJson({
          ...assignmentBody(status: 'COMPLETED'),
          'myReview': null,
          'counterpartyReviewed': false,
        });

        expect(assignment.myReview, isNull);
        expect(assignment.counterpartyReviewed, isFalse);
      });

      // Eski sunucu alanları hiç göndermiyor: düğme görünür kalsın, karşı
      // taraf rozeti çizilmesin.
      test('eski sunucu alanları göndermezse null / false', () {
        final assignment = Assignment.fromJson(
          assignmentBody(status: 'COMPLETED'),
        );

        expect(assignment.myReview, isNull);
        expect(assignment.counterpartyReviewed, isFalse);
      });
    });
  });

  group('AssignmentPage', () {
    test('boş içerik hata değil', () {
      final page = AssignmentPage.fromJson({'content': []});

      expect(page.assignments, isEmpty);
      expect(page.last, isTrue);
    });

    test('içerik listesi ayrıştırılır', () {
      final page = AssignmentPage.fromJson({
        'content': [assignmentBody()],
        'totalElements': 1,
        'last': false,
      });

      expect(page.assignments, hasLength(1));
      expect(page.totalElements, 1);
      expect(page.last, isFalse);
    });
  });

  // İşlerim ekranının beş durumu backend'in iki kavramına yayılıyor;
  // eşleme yanlışsa kullanıcı bitmiş işi "devam ediyor" görür.
  group('MyJob.fromAssignment', () {
    test('sohbet açmak için ilan kimliğini korur', () {
      final myJob = MyJob.fromAssignment(Assignment.fromJson(assignmentBody()));

      expect(myJob.jobId, 'job_1');
    });

    test('mesajlaşma kapısını atamadan taşır', () {
      expect(
        MyJob.fromAssignment(
          Assignment.fromJson(
            assignmentBody(
              messagingAvailable: true,
              messagingAvailableReason: 'AVAILABLE',
            ),
          ),
        ).messaging.isAvailable,
        isTrue,
      );
      expect(
        MyJob.fromAssignment(
          Assignment.fromJson(assignmentBody()),
        ).messaging.isAvailable,
        isFalse,
      );
    });

    // Başvurudan gelen satırın ataması yok; ödeme de yok. Kapı kapalı
    // başlamalı ki eski sunucuya karşı da düğme çıkmasın.
    test('başvurudan kurulan satırda kapı kapalı başlar', () {
      const myJob = MyJob(
        id: 'app_1',
        jobId: 'job_1',
        title: 'Garson',
        company: 'Kafe',
        description: '',
        date: '',
        price: 100,
        status: MyJobStatus.pending,
      );

      expect(myJob.messaging.isAvailable, isFalse);
      expect(myJob.messaging.needsPayment, isTrue);
    });

    MyJob mapWith({required String status, String payment = 'HELD_IN_ESCROW'}) {
      return MyJob.fromAssignment(
        Assignment.fromJson(
          assignmentBody(status: status, paymentStatus: payment),
        ),
      );
    }

    // Sıra çalışanda: iş, atama kabul edilene kadar başlamıyor. Bu yüzden
    // "onaylandı" ile aynı kovaya giremez, ekranda ayrı bölümü var.
    test('cevap bekleyen atama "onayın bekleniyor" olur', () {
      expect(
        mapWith(status: 'PENDING_CONFIRMATION').status,
        MyJobStatus.awaitingApproval,
      );
    });

    test('onaylanmış iş "onaylandı" olur', () {
      expect(mapWith(status: 'CONFIRMED').status, MyJobStatus.approved);
    });

    // Mesai başlamış: ekranda çıkış butonu çıkıyor, giriş butonu değil.
    test('süren iş "devam ediyor" olur', () {
      expect(mapWith(status: 'IN_PROGRESS').status, MyJobStatus.inProgress);
    });

    // Sunucu para emanete geçmeden mesai başlatmıyor; buton bu bilgiye
    // bakarak kapanıyor, 409 beklemiyor.
    test('ödeme emanetteyken mesai başlatılabilir işaretlenir', () {
      expect(
        mapWith(
          status: 'CONFIRMED',
          payment: 'HELD_IN_ESCROW',
        ).isPaymentSecured,
        isTrue,
      );
      expect(
        mapWith(
          status: 'CONFIRMED',
          payment: 'PENDING_COLLECTION',
        ).isPaymentSecured,
        isFalse,
      );
    });

    // Atama uçları id'yi buradan okuyor; başvurudan gelen satırlarda `null`.
    test('atamadan gelen kayıt assignmentId taşır', () {
      expect(mapWith(status: 'CONFIRMED').assignmentId, isNotNull);
    });

    test('biten iş ödeme yapılmadıysa "ödeme bekleniyor"', () {
      expect(
        mapWith(status: 'COMPLETED', payment: 'HELD_IN_ESCROW').status,
        MyJobStatus.completed,
      );
    });

    test('biten iş ödeme yapıldıysa "geçmiş"', () {
      expect(
        mapWith(status: 'COMPLETED', payment: 'RELEASED_TO_WORKER').status,
        MyJobStatus.past,
      );
    });

    // Eskiden listeden düşüyorlardı; kullanıcı işin neden kaybolduğunu
    // değil ne olduğunu görebilmeli.
    test('iptal ve red kendi durumlarına düşer', () {
      expect(mapWith(status: 'CANCELLED').status, MyJobStatus.cancelled);
      expect(mapWith(status: 'REJECTED').status, MyJobStatus.rejected);
    });

    test('kapanmış işler isClosed', () {
      expect(mapWith(status: 'CANCELLED').isClosed, isTrue);
      expect(mapWith(status: 'REJECTED').isClosed, isTrue);
      expect(
        mapWith(status: 'COMPLETED', payment: 'RELEASED_TO_WORKER').isClosed,
        isTrue,
      );
      expect(mapWith(status: 'CONFIRMED').isClosed, isFalse);
    });

    test('gösterilen ücret çalışanın kazancı, ilan ücreti değil', () {
      final myJob = mapWith(status: 'CONFIRMED');

      expect(myJob.price, 1350);
    });

    test('kazanç gelmezse ilan ücretine düşülür', () {
      final myJob = MyJob.fromAssignment(
        Assignment.fromJson(assignmentBody(workerPayout: null)),
      );

      expect(myJob.price, 1500);
    });

    test('bireysel ilanda şirket yerine yer tutucu yazılır', () {
      final body = assignmentBody();
      (body['job'] as Map<String, dynamic>).remove('companyName');

      final myJob = MyJob.fromAssignment(Assignment.fromJson(body));

      expect(myJob.company, 'Bireysel İlan');
      expect(myJob.companyId, isNull);
    });

    test('şirket ilanında companyId kopyalanır', () {
      final body = assignmentBody();
      (body['job'] as Map<String, dynamic>)['companyId'] = 'comp_7';

      final myJob = MyJob.fromAssignment(Assignment.fromJson(body));

      expect(myJob.companyId, 'comp_7');
    });

    test('tarih gg.aa.yyyy biçiminde yazılır', () {
      expect(mapWith(status: 'CONFIRMED').date, '10.03.2026');
    });

    test('işveren türü, ödeme durumu ve kaynak atama satıra taşınır', () {
      final body = assignmentBody();
      (body['job'] as Map<String, dynamic>)['employerType'] = 'INDIVIDUAL';

      final assignment = Assignment.fromJson(body);
      final myJob = MyJob.fromAssignment(assignment);

      expect(myJob.employerType, JobEmployerType.individual);
      expect(myJob.paymentStatus, PaymentStatus.heldInEscrow);
      expect(myJob.assignment, same(assignment));
      expect(myJob.application, isNull);
      expect(myJob.applicationDateTime, isNull);
      expect(myJob.answeredDateTime, isNull);
    });

    test('atamanın şirket alanı ilan özetindeki addan önce gelir', () {
      final myJob = MyJob.fromAssignment(
        Assignment.fromJson({
          ...assignmentBody(),
          'application': {
            'id': 'app_1',
            'applicationDateTime': '2026-03-01T10:00:00Z',
            'answeredDateTime': '2026-03-02T08:00:00Z',
          },
          'company': {'id': 'comp_7', 'name': 'Koala Etkinlik'},
        }),
      );

      expect(myJob.company, 'Koala Etkinlik');
      expect(myJob.companyId, 'comp_7');
      expect(myJob.applicationDateTime, DateTime.utc(2026, 3, 1, 10));
      expect(myJob.answeredDateTime, DateTime.utc(2026, 3, 2, 8));
    });
  });

  // İşlerim menüsü ve iş detayı aynı kuralları buradan okuyor; sayfalar
  // durumdan yeniden türetmiyor.
  group('MyJob eylem kuralları', () {
    MyJob row(String status, {String paymentStatus = 'HELD_IN_ESCROW'}) =>
        MyJob.fromAssignment(
          Assignment.fromJson(
            assignmentBody(status: status, paymentStatus: paymentStatus),
          ),
        );

    test('iptal yalnız onaylanmış ve süren işte', () {
      expect(row('CONFIRMED').canCancel, isTrue);
      expect(row('IN_PROGRESS').canCancel, isTrue);
      expect(row('PENDING_CONFIRMATION').canCancel, isFalse);
      expect(row('COMPLETED').canCancel, isFalse);
      expect(row('CANCELLED').canCancel, isFalse);
    });

    test('sorun bildirme para emanetteyken, süren ve biten işte', () {
      expect(row('IN_PROGRESS').canDispute, isTrue);
      expect(
        row('COMPLETED', paymentStatus: 'PENDING_COLLECTION').canDispute,
        isFalse,
      );
      expect(row('COMPLETED').canDispute, isTrue);
      expect(row('CONFIRMED').canDispute, isFalse);
    });

    test('geri çekme yalnız bekleyen başvuruda, atama satırında değil', () {
      expect(row('PENDING_CONFIRMATION').canWithdraw, isFalse);
      const pending = MyJob(
        id: 'app_1',
        jobId: 'job_1',
        title: 'Garson',
        company: 'Koala Cafe',
        description: 'Garson',
        date: '',
        price: 500,
        status: MyJobStatus.pending,
      );
      expect(pending.canWithdraw, isTrue);
      expect(pending.canCancel, isFalse);
      expect(pending.canDispute, isFalse);
    });
  });
}
