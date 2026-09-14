import 'package:koala/employee/features/chat/models/messaging_availability.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/product/extensions/date_extensions.dart';

enum MyJobStatus {
  pending, // Başvuruldu, işverenin onayı bekleniyor
  awaitingApproval, // İşveren kabul etti, çalışanın onayı bekleniyor
  approved, // İki taraf da onayladı, gidilmesi bekleniyor
  inProgress, // Mesai başladı, çıkış bekleniyor
  completed, // İş bitti, ödeme bekleniyor
  past, // Ödeme alındı, geçmişe taşındı
  rejected, // Çalışan işi kabul etmedi
  applicationRejected, // İşveren başvuruyu reddetti
  cancelled, // İki taraftan biri işi iptal etti
  withdrawn, // Başvuran başvurusunu geri çekti
  unknown, // Sunucudan bu sürümün tanımadığı bir durum geldi
}

extension MyJobStatusExtension on MyJobStatus {
  String get displayName {
    switch (this) {
      case MyJobStatus.pending:
        return 'Başvuru Bekliyor';
      case MyJobStatus.awaitingApproval:
        return 'Onayın Bekleniyor';
      case MyJobStatus.approved:
        return 'Onaylandı';
      case MyJobStatus.inProgress:
        return 'Devam Ediyor';
      case MyJobStatus.completed:
        return 'Ödeme Bekleniyor';
      case MyJobStatus.past:
        return 'Tamamlandı';
      case MyJobStatus.rejected:
        return 'Reddedildi';
      case MyJobStatus.applicationRejected:
        return 'Başvuru Reddedildi';
      case MyJobStatus.cancelled:
        return 'İptal Edildi';
      // İki "geri çekildi" arasında fark yok ama özne var: bunu kullanıcının
      // kendisi yaptı, o yüzden ikinci tekil.
      case MyJobStatus.withdrawn:
        return 'Geri Çektin';
      case MyJobStatus.unknown:
        return 'Bilinmiyor';
    }
  }

  String get description {
    switch (this) {
      case MyJobStatus.pending:
        return 'Başvurunuz değerlendiriliyor';
      case MyJobStatus.awaitingApproval:
        return 'İşveren sizi seçti, işi onaylamanız bekleniyor';
      case MyJobStatus.approved:
        return 'İşe gitmeniz bekleniyor';
      case MyJobStatus.inProgress:
        return 'Mesainiz sürüyor';
      case MyJobStatus.completed:
        return 'Ödemeniz işleniyor';
      case MyJobStatus.past:
        return 'Ödeme alındı';
      case MyJobStatus.rejected:
        return 'Bu işi kabul etmediniz';
      // İki "reddedildi" birbirinin aynısı değil: bunu işveren yaptı,
      // yukarıdakini çalışanın kendisi. Aynı metni vermek kimin karar
      // verdiğini gizlerdi.
      case MyJobStatus.applicationRejected:
        return 'İşveren başka bir adayla devam etti';
      case MyJobStatus.cancelled:
        return 'İş iptal edildi';
      case MyJobStatus.withdrawn:
        return 'Başvurunu geri çektin';
      // Kullanıcıya sunucunun kod adını göstermenin faydası yok; yapabileceği
      // tek şey uygulamayı güncellemek.
      case MyJobStatus.unknown:
        return 'Bu kaydın durumu uygulamanın bu sürümünde tanınmıyor';
    }
  }
}

class MyJob {
  /// Satırın kimliği: başvurudan gelen kayıtlarda başvurunun, atamadan
  /// gelenlerde atamanın id'si. Atama uçlarına gidecek olan [assignmentId].
  final String id;

  /// Sohbetin ve ilan detayının bağlı olduğu asıl ilan kimliği.
  final String? jobId;
  final String title;
  final String company;
  final String? companyId;
  final String description;
  final String date;
  final double price;
  final MyJobStatus status;

  /// Para emanete alınmış mı.
  ///
  /// Sunucu, ücret emanete (`HELD_IN_ESCROW`) geçmeden mesai başlatmıyor.
  /// Butonu `409` alana kadar açık bırakmak yerine burada kapatılıyor ki
  /// kullanıcı sebebini önden görsün. Başvurudan gelen satırlarda `false`.
  final bool isPaymentSecured;

  /// İşverenin başvuruyu reddederken yazdığı gerekçe. Yalnızca
  /// [MyJobStatus.applicationRejected] satırlarda dolu; işveren gerekçe
  /// yazmak zorunda değil, o yüzden `null` olabilir.
  final String? rejectionReason;

  /// İşverenle sohbet açılabilir mi.
  ///
  /// Sunucu ödeme emanete geçmeden sohbeti reddediyor
  /// (`403 MESSAGING_PAYMENT_REQUIRED`); düğme onu beklemek yerine burada
  /// gizleniyor ve yerine sebep yazılıyor. Başvurudan gelen satırlarda
  /// varsayılan [MessagingAvailability.paymentRequired]: ortada atama yok,
  /// dolayısıyla ödeme de yok.
  final MessagingAvailability messaging;

  /// Atamanın id'si; kayıt bir başvurudan geliyorsa `null`.
  ///
  /// Atama uçları (`/job-assignments/...`) bunu istiyor; [id] ile aynı değeri
  /// taşıyor ama ayrı durması, hangi satırın atama olduğunu tip üzerinden
  /// belli ediyor.
  final String? assignmentId;

  /// İlanı kimin açtığı: şirket mi, bireysel işveren mi. Satırdaki rozet ve
  /// detaydaki işveren kartı buna bakıyor.
  final JobEmployerType employerType;

  /// Başvurunun yapıldığı an; başvurudan **ve** atamadan gelen satırlarda
  /// (atama `application.applicationDateTime` gönderiyorsa) dolu.
  final DateTime? applicationDateTime;

  /// İşverenin başvuruyu yanıtladığı an. Yanıtlanmamış başvuruda `null`.
  final DateTime? answeredDateTime;

  /// Ödemenin sunucudaki durumu; başvurudan gelen satırlarda `null` — ortada
  /// atama, dolayısıyla ödeme yok. [isPaymentSecured] bunun tek bir sorusuna
  /// cevap; detay sayfası dört durumun her birini ayrı yazıyor.
  final PaymentStatus? paymentStatus;

  /// Satırın türediği kayıt. İkisinden **tam biri** dolu: atamadan gelen
  /// satırda [assignment], başvurudan gelende [application]. Detay sayfası
  /// satırı değil kaydı okuyor — çizelge, işveren ve iptal bilgisi burada.
  final Assignment? assignment;
  final JobApplication? application;

  const MyJob({
    required this.id,
    this.jobId,
    required this.title,
    required this.company,
    this.companyId,
    required this.description,
    required this.date,
    required this.price,
    required this.status,
    this.assignmentId,
    this.isPaymentSecured = false,
    this.rejectionReason,
    this.messaging = MessagingAvailability.paymentRequired,
    this.employerType = JobEmployerType.company,
    this.applicationDateTime,
    this.answeredDateTime,
    this.paymentStatus,
    this.assignment,
    this.application,
  });

  /// İş kapandı mı: üzerinde yapılacak bir şey kalmayan her satır.
  ///
  /// Geçmişe düşen, iptal edilen, reddedilen, geri çekilen ve durumu
  /// tanınmayan kayıtlar; ekranda hepsi aynı bölümde duruyor.
  ///
  /// Elle yazılmış bir `||` zinciriydi ve derleyici sessiz kalıyordu: yeni bir
  /// [MyJobStatus] eklenince kayıt hiçbir bölüme girmeden ekrandan düşüyordu.
  /// Exhaustive `switch` aynı hatayı bir daha derleme hatasına çeviriyor.
  bool get isClosed => switch (status) {
    MyJobStatus.past ||
    MyJobStatus.rejected ||
    MyJobStatus.applicationRejected ||
    MyJobStatus.cancelled ||
    MyJobStatus.withdrawn ||
    MyJobStatus.unknown => true,
    MyJobStatus.pending ||
    MyJobStatus.awaitingApproval ||
    MyJobStatus.approved ||
    MyJobStatus.inProgress ||
    MyJobStatus.completed => false,
  };

  /// Satırın alt satırında gösterilecek metin.
  ///
  /// Reddedilen başvuruda işverenin yazdığı gerekçe ilanın özetinden daha
  /// değerli: kullanıcının öğrenmek istediği tek şey o.
  String get subtitle {
    final reason = rejectionReason;

    return status == MyJobStatus.applicationRejected &&
            reason != null &&
            reason.trim().isNotEmpty
        ? reason
        : description;
  }

  /// Bir atamayı ekranın bildiği [MyJob] durumlarına çevirir.
  ///
  /// Her atama durumunun artık bir karşılığı var; eskiden iptal ve red
  /// listeden düşüyordu, o yüzden dönüş nullable'dı.
  static MyJob fromAssignment(Assignment assignment) {
    final status = switch (assignment.status) {
      // İşveren kabul etti ama iş henüz başlamadı: sıra çalışanda.
      AssignmentStatus.pendingConfirmation => MyJobStatus.awaitingApproval,
      AssignmentStatus.confirmed => MyJobStatus.approved,
      // Mesai başlamış: giriş yapılmış ama iş henüz kapanmamış.
      AssignmentStatus.inProgress => MyJobStatus.inProgress,
      // İş bitti: para çalışana geçtiyse geçmiş, geçmediyse ödeme bekliyor.
      AssignmentStatus.completed =>
        assignment.paymentStatus.isPaid
            ? MyJobStatus.past
            : MyJobStatus.completed,
      // Kapanmış işler de listede duruyor: kullanıcı bir işin neden
      // kaybolduğunu değil, ne olduğunu görebilmeli.
      AssignmentStatus.rejected => MyJobStatus.rejected,
      AssignmentStatus.cancelled => MyJobStatus.cancelled,
    };

    final job = assignment.job;

    return MyJob(
      id: assignment.id,
      jobId: job.id,
      title: job.title,
      company: assignment.company?.name ?? job.company ?? 'Bireysel İlan',
      // Şirket kimliği iki yerden gelebiliyor: atamanın kendi `company`
      // alanı (koala-backend#282) ya da ilan özetinin `companyId`'si.
      companyId: assignment.company?.id ?? job.companyId,
      description: job.subtitle,
      date: assignment.assignmentDateTime?.asShortDate ?? '',
      // Çalışanın eline geçecek tutar komisyon düşülmüş hâli; ilandaki ücret
      // değil o gösterilmeli.
      price: assignment.workerPayout ?? job.price,
      status: status,
      assignmentId: assignment.id,
      isPaymentSecured: assignment.paymentStatus == PaymentStatus.heldInEscrow,
      messaging: assignment.messaging,
      employerType: job.employerType,
      applicationDateTime: assignment.application?.applicationDateTime,
      answeredDateTime: assignment.application?.answeredDateTime,
      paymentStatus: assignment.paymentStatus,
      assignment: assignment,
    );
  }

  /// Bir başvuruyu ekranın bildiği [MyJob] durumlarına çevirir; listede yeri
  /// yoksa `null` döner.
  ///
  /// Her başvuru durumunun ekranda ne olacağına **tek bir exhaustive
  /// `switch`** karar veriyor: `null` "listede yeri yok" demek. Eleme ayrı bir
  /// `if` olarak dursaydı switch'te ulaşılamaz bir dal kalır, o dal da bir
  /// gün eleme kalktığında sessizce yanlış durumu çizerdi.
  static MyJob? fromApplication(JobApplication application) {
    final status = switch (application.status) {
      ApplicationStatus.applied => MyJobStatus.pending,
      ApplicationStatus.rejected => MyJobStatus.applicationRejected,
      ApplicationStatus.withdrawn => MyJobStatus.withdrawn,
      // **Bilinmeyen durum kararı.** Satır listeden düşürülmüyor: sunucuda
      // kullanıcının bir kaydı var ve onu gizlemek "başvurum kayboldu"
      // demek olurdu. Ama bilinen bir durum gibi de çizilmiyor; kapalı
      // sayılıp geçmişe konuyor, çünkü ne olduğunu bilmediğimiz bir kayıt
      // üzerinde önerebileceğimiz hiçbir eylem yok.
      ApplicationStatus.unknown => MyJobStatus.unknown,
      // **Kabul edilen başvuru atlanıyor.** O başvuru artık bir atama ve
      // atamalar uçtan ayrıca geliyor; ikisini birden çizmek aynı işi
      // listede iki kez gösterirdi.
      ApplicationStatus.accepted => null,
    };

    if (status == null) return null;

    final job = application.job;

    return MyJob(
      id: application.id,
      jobId: job.id,
      title: job.title,
      company: job.company ?? 'Bireysel İlan',
      // `MyApplicationDto.job` bir `JobSummaryDto`, yani `companyId`
      // taşıyor; sabit `null` yazmak şirket bağlantısını her satırda
      // öldürüyordu (is-koala/koala#177).
      companyId: job.companyId,
      description: job.subtitle,
      date: application.applicationDateTime?.asShortDate ?? '',
      price: job.price,
      status: status,
      rejectionReason: application.rejectionReason,
      employerType: job.employerType,
      applicationDateTime: application.applicationDateTime,
      answeredDateTime: application.answeredDateTime,
      application: application,
    );
  }
}
