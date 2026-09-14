import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';

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

    test('eski sunucu alanları göndermezse kapı kapalı', () {
      final assignment = Assignment.fromJson(assignmentBody());

      expect(assignment.messaging.isAvailable, isFalse);
      expect(assignment.messaging.needsPayment, isTrue);
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
  });
}
