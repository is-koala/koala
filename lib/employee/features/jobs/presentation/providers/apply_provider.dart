import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_exception.dart';

/// Kullanıcının başvuruları.
///
/// Başvuru göndermek ilan üzerinden, listelemek kullanıcı üzerinden yapılıyor;
/// ikisi de [JobApplicationService]'te. Gönderim başarılı olduğunda liste
/// yeniden çekilmiyor, dönen kayıt doğrudan başa ekleniyor — kullanıcı
/// sonucu anında görüyor.
class ApplyProvider extends ChangeNotifier {
  ApplyProvider({JobApplicationService? service})
    : _service = service ?? JobApplicationService();

  final JobApplicationService _service;

  final List<JobApplication> _applications = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  /// Son hatanın makine okunur kodu.
  ///
  /// Başvuru kapısının üç şartı (`APPLICANT_IDENTITY_NOT_VERIFIED`,
  /// `APPLICANT_ADDRESS_REQUIRED`, `APPLICANT_BANK_ACCOUNT_REQUIRED`) ayrı
  /// kodlarla geliyor; ekran doğru düzeltme adımına yönlendirmek için
  /// mesaja değil buna bakıyor.
  String? _errorCode;

  /// Geri çekme isteği sunucuya gitmiş başvurunun kimliği.
  ///
  /// Tek bir alan yetiyor: kullanıcı aynı anda tek bir başvuruyu geri
  /// çekiyor. Ekran satırın düğmesini buna bakarak kilitliyor.
  String? _withdrawingId;

  List<JobApplication> get applications => List.unmodifiable(_applications);

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  String? get errorCode => _errorCode;

  /// Geri çekme isteği süren başvurunun kimliği; yoksa `null`.
  String? get withdrawingId => _withdrawingId;

  /// Başvuruların "İşlerim" ekranındaki karşılığı.
  ///
  /// Ekran hâlâ [MyJob] üzerinden çiziliyor. Kabul edilmiş başvuru bir
  /// atamaya dönüştüğü için buraya girmiyor; kalan dört durumun her birinin
  /// kendi satırı var — bkz. [_toMyJob].
  List<MyJob> get appliedJobs =>
      _applications.map(_toMyJob).nonNulls.toList(growable: false);

  /// Bu ilana yeniden başvurmayı engelleyen bir kayıt var mı.
  ///
  /// Geri çekilmiş başvuru saymıyor: sunucu o ilana yeniden başvurmaya izin
  /// veriyor ([ApplicationStatus.blocksReapplication]). Burası saysaydı
  /// sunucunun kuralı uygulamadan hiç erişilemez kalırdı — [applyToJob]
  /// isteği atmadan `false` dönüyor.
  bool hasApplied(String jobId) {
    return _applications.any(
      (application) =>
          application.job.id == jobId && application.status.blocksReapplication,
    );
  }

  /// Başvuruları sunucudan çeker.
  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force && _errorMessage == null) return;

    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final page = await _service.fetchMyApplications();
      _applications
        ..clear()
        ..addAll(page.applications);
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _errorCode = error.errorCode;
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  /// Bir ilana başvurur.
  ///
  /// Başarılıysa `true` döner. Sunucu aynı ilana ikinci başvuruyu reddediyor;
  /// o durumda mesaj [errorMessage]'a düşüyor ve `false` dönüyor.
  Future<bool> applyToJob(Job job, {String? coverLetter}) async {
    if (hasApplied(job.id)) return false;

    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final application = await _service.apply(
        jobId: job.id,
        notes: coverLetter,
      );
      _applications.insert(0, application);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _errorCode = error.errorCode;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Başvuruyu geri çeker.
  ///
  /// Başarılıysa `true` döner. Sunucu yalnızca `APPLIED` durumundan geçiriyor;
  /// yanıtlanmış ya da zaten geri çekilmiş başvuruda `409` dönüyor.
  ///
  /// **Yalnızca durum sunucudan alınıyor, kayıt olduğu gibi değiştirilmiyor.**
  /// Uç `JobApplicationDetailDto` döndürüyor ve onun `job` alanı
  /// `ShortJobDto` — yalnızca id ve başlık. Kaydı yerine koysaydık satırın
  /// ücreti, şirketi ve özeti silinir, "Geçmiş" bölümünde ₺0'lık bir satır
  /// kalırdı. Liste yeniden çekilmiyor: kullanıcı sonucu anında görüyor.
  Future<bool> withdraw(String applicationId) async {
    if (_withdrawingId != null) return false;

    _withdrawingId = applicationId;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final withdrawn = await _service.withdraw(applicationId);
      final index = _applications.indexWhere(
        (application) => application.id == applicationId,
      );
      if (index != -1) {
        _applications[index] = _applications[index].copyWith(
          status: withdrawn.status,
        );
      }
      return true;
    } on ApiException catch (error) {
      // 409: başvuru araya girip kabul ya da reddedilmiş demektir, ekrandaki
      // liste bayat. Tazeleme mesajdan **önce** çalışıyor: [load] başlarken
      // hata alanlarını temizliyor, ters sırada kullanıcıya gösterilecek
      // mesaj kaybolurdu.
      if (error.type.serverStateMoved) await load(force: true);
      _errorMessage = error.message;
      _errorCode = error.errorCode;
      return false;
    } finally {
      _withdrawingId = null;
      notifyListeners();
    }
  }

  /// Çıkışta önceki kullanıcının başvuruları kalmasın.
  void clear() {
    _applications.clear();
    _errorMessage = null;
    _errorCode = null;
    _hasLoaded = false;
    notifyListeners();
  }

  /// Başvuruyu ekranın satırına çevirir; listede yeri yoksa `null` döner.
  ///
  /// Her başvuru durumunun ekranda ne olacağına **tek bir exhaustive
  /// `switch`** karar veriyor: `null` "listede yeri yok" demek. Eleme ayrı bir
  /// `if` olarak dursaydı switch'te ulaşılamaz bir dal kalır, o dal da bir
  /// gün eleme kalktığında sessizce yanlış durumu çizerdi.
  static MyJob? _toMyJob(JobApplication application) {
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
    final date = application.applicationDateTime;

    return MyJob(
      id: application.id,
      jobId: job.id,
      title: job.title,
      company: job.company ?? 'Bireysel İlan',
      companyId: null,
      description: job.subtitle,
      date: date?.asShortDate ?? '',
      price: job.price,
      status: status,
      rejectionReason: application.rejectionReason,
    );
  }
}
