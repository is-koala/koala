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
      // Bunu kullanıcı kendisi yaptı; ikinci tekil.
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
      // Bunu işveren yaptı; aynı metin kimin karar verdiğini gizlerdi.
      case MyJobStatus.applicationRejected:
        return 'İşveren başka bir adayla devam etti';
      case MyJobStatus.cancelled:
        return 'İş iptal edildi';
      case MyJobStatus.withdrawn:
        return 'Başvurunu geri çektin';
      // Kod adını göstermek fayda etmez; yapılacak tek şey güncellemek.
      case MyJobStatus.unknown:
        return 'Bu kaydın durumu uygulamanın bu sürümünde tanınmıyor';
    }
  }
}

class MyJob {
  /// Başvuru satırında başvurunun, atama satırında atamanın id'si; atama uçları
  /// için [assignmentId].
  final String id;

  final String? jobId;
  final String title;
  final String company;
  final String? companyId;
  final String description;
  final String date;
  final double price;
  final MyJobStatus status;

  /// Sunucu emanet olmadan mesai başlatmıyor; buton `409` beklemeden kapanır.
  /// Başvuru satırlarında `false`.
  final bool isPaymentSecured;

  /// Yalnız [MyJobStatus.applicationRejected]'da; gerekçe zorunlu değil.
  final String? rejectionReason;

  /// Sohbet açılabilir mi; ödeme emanete geçmeden sunucu reddediyor. Başvuru
  /// satırlarında [MessagingAvailability.paymentRequired].
  final MessagingAvailability messaging;

  /// Başvuru satırında `null`; hangi satırın atama olduğunu tip anlatıyor.
  final String? assignmentId;

  final JobEmployerType employerType;

  final DateTime? applicationDateTime;

  final DateTime? answeredDateTime;

  /// Başvuru satırında `null`. [isPaymentSecured] bunun tek sorusu.
  final PaymentStatus? paymentStatus;

  /// İkisinden **tam biri** dolu; detay sayfası satırı değil kaydı okuyor.
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

  /// İş kapandı mı; kapalılar aynı bölümde. Exhaustive `switch`: yeni
  /// [MyJobStatus] hiçbir bölüme girmeden ekrandan düşmesin.
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

  /// Kapı ayrı ([messaging]); bu yalnız kaydın durumuna bakıyor.
  bool get offersChat =>
      jobId != null &&
      switch (status) {
        MyJobStatus.pending ||
        MyJobStatus.awaitingApproval ||
        MyJobStatus.approved ||
        MyJobStatus.inProgress ||
        MyJobStatus.completed => true,
        MyJobStatus.past ||
        MyJobStatus.rejected ||
        MyJobStatus.applicationRejected ||
        MyJobStatus.cancelled ||
        MyJobStatus.withdrawn ||
        MyJobStatus.unknown => false,
      };

  /// Sunucu `PENDING_CONFIRMATION`, `CONFIRMED`, `IN_PROGRESS` dışında `409`;
  /// cevap bekleyende iptal yerine "Reddet" var.
  bool get canCancel =>
      assignmentId != null &&
      (status == MyJobStatus.approved || status == MyJobStatus.inProgress);

  /// Yalnız para emanetteyken ve iş sürerken ya da ödeme beklerken.
  bool get canDispute =>
      assignmentId != null &&
      isPaymentSecured &&
      (status == MyJobStatus.inProgress || status == MyJobStatus.completed);

  /// Yalnız `APPLIED`; atama satırı elenir, geri çekme başvurunun kimliğini
  /// istiyor.
  bool get canWithdraw => status == MyJobStatus.pending && assignmentId == null;

  /// Reddedilende işverenin gerekçesi özetten değerli.
  String get subtitle {
    final reason = rejectionReason;

    return status == MyJobStatus.applicationRejected &&
            reason != null &&
            reason.trim().isNotEmpty
        ? reason
        : description;
  }

  /// Her atama durumunun karşılığı var; iptal ve red de listede.
  static MyJob fromAssignment(Assignment assignment) {
    final status = switch (assignment.status) {
      // Kabul edildi, sıra çalışanda.
      AssignmentStatus.pendingConfirmation => MyJobStatus.awaitingApproval,
      AssignmentStatus.confirmed => MyJobStatus.approved,
      AssignmentStatus.inProgress => MyJobStatus.inProgress,
      AssignmentStatus.completed =>
        assignment.paymentStatus.isPaid
            ? MyJobStatus.past
            : MyJobStatus.completed,
      // Kapanmış işler de listede: kullanıcı ne olduğunu görebilmeli.
      AssignmentStatus.rejected => MyJobStatus.rejected,
      AssignmentStatus.cancelled => MyJobStatus.cancelled,
    };

    final job = assignment.job;

    return MyJob(
      id: assignment.id,
      jobId: job.id,
      title: job.title,
      company: assignment.company?.name ?? job.company ?? 'Bireysel İlan',
      companyId: assignment.company?.id ?? job.companyId,
      description: job.subtitle,
      date: assignment.assignmentDateTime?.asShortDate ?? '',
      // Komisyon düşülmüş tutar gösterilmeli.
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

  /// Başvuruyu çevirir; listede yeri yoksa `null`. Karar tek exhaustive
  /// `switch`'te.
  static MyJob? fromApplication(JobApplication application) {
    final status = switch (application.status) {
      ApplicationStatus.applied => MyJobStatus.pending,
      ApplicationStatus.rejected => MyJobStatus.applicationRejected,
      ApplicationStatus.withdrawn => MyJobStatus.withdrawn,
      // **Bilinmeyen durum:** listeden düşmez ("başvurum kayboldu" olur) ama
      // kapalı sayılıp geçmişe konur; önerilecek eylem yok.
      ApplicationStatus.unknown => MyJobStatus.unknown,
      // **Kabul edilen atlanıyor:** artık atama, iki kez görünmesin.
      ApplicationStatus.accepted => null,
    };

    if (status == null) return null;

    final job = application.job;

    return MyJob(
      id: application.id,
      jobId: job.id,
      title: job.title,
      company: job.company ?? 'Bireysel İlan',
      // `JobSummaryDto` `companyId` taşıyor; şirket bağlantısı kalsın (#177).
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
