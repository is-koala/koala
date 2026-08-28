import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/b_job_post.dart';
import 'package:koala/business/features/home/models/create_job_request.dart';
import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// İşverenin ilanları ve o ilanlara gelen başvurular.
///
/// Veri iki uçtan geliyor ama **aynı anda değil**:
/// - `GET /users/me/jobs` → ilanların özeti, başvuru sayısı dâhil,
/// - `GET /jobs/{jobId}/applications` → yalnızca başvuranların kendisi.
///
/// Sunucu `JobSummaryDto.applicationCount` döndürdüğü için sayıyı göstermek
/// istek gerektirmiyor. Başvuranların kim olduğu ise ancak birkaç yerde
/// gerekiyor: ilan detayı, ana sayfadaki son başvurular ve geçmiş ilanın işi
/// alan kişisi. O yüzden başvurular toptan değil, [ensureApplicants] ile ilan
/// ilan ve istendiğinde çekiliyor — listeyi çizmek için asla.
class BJobsProvider extends ChangeNotifier {
  BJobsProvider({EmployerJobService? service})
    : _service = service ?? EmployerJobService();

  final EmployerJobService _service;

  List<BJobPost> _jobPosts = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  List<BJobPost> get allPosts => List.unmodifiable(_jobPosts);

  /// Yürürlükteki ilanlar — "Aktif" sekmesi.
  List<BJobPost> get activePosts =>
      _jobPosts.where((post) => post.isActive).toList();

  /// Kapanmış, tamamlanmış ya da iptal edilmiş ilanlar — "Geçmiş" sekmesi.
  List<BJobPost> get pastPosts =>
      _jobPosts.where((post) => !post.isActive).toList();

  bool get isLoading => _isLoading;

  /// Liste bir kez çekildi mi. Hata da olsa `true`; tekrar denemek çağıranın
  /// açık kararı olmalı.
  bool get hasLoaded => _hasLoaded;

  /// Son işlemin hata mesajı. Bir sonraki işlemde temizleniyor.
  String? get errorMessage => _errorMessage;

  /// Hiç ilan yok mu. Hata durumundan ayrı: boş liste bir arıza değil.
  bool get isEmpty => _hasLoaded && _jobPosts.isEmpty && _errorMessage == null;

  /// Aktif ilanlara gelen toplam başvuru sayısı.
  ///
  /// Sayı ilan listesiyle birlikte geldiği için başvuranları çekmeye gerek
  /// yok; yanıtlanmış başvurular da bu toplama dâhil.
  int get totalApplicantCount =>
      activePosts.fold<int>(0, (sum, post) => sum + post.job.applicationCount);

  /// İlan listesini çeker. Başvuranlar gelmiyor — bkz. [ensureApplicants].
  ///
  /// Daha önce başarıyla çekildiyse ağa çıkmaz; [force] ile yenilenir.
  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force && _errorMessage == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _service.fetchMyJobs();
      _jobPosts = [for (final job in page.jobs) BJobPost(job: job)];
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  /// Uçuşta olan başvuru istekleri; aynı ilan iki kez istenmesin diye.
  final Set<String> _pendingApplicantRequests = {};

  /// Bir ilanın başvuranlarını, daha önce çekilmediyse çeker.
  ///
  /// Aynı ilan için ikinci kez çağrılmak zararsız: elde veri varsa ağa
  /// çıkmıyor. Ekranlar bunu ihtiyaç duydukları anda çağırıyor — ilan
  /// listesindeki sayı ilanla birlikte geldiği için liste bu isteği hiç
  /// atmıyor.
  ///
  /// Başvurular alınamazsa liste hataya düşmüyor: o ilan başvurusuz
  /// görünüyor. Ekranı kaplayan bir hata elde duran ilanları da gizlerdi.
  Future<void> ensureApplicants(String jobId, {bool force = false}) async {
    final index = _jobPosts.indexWhere((post) => post.job.id == jobId);
    if (index == -1) return;
    if (_jobPosts[index].applicantsLoaded && !force) return;
    if (!_pendingApplicantRequests.add(jobId)) return;

    List<JobApplicant> applicants = const [];
    try {
      applicants = await _service.fetchApplicants(jobId);
    } on ApiException {
      // Yutuluyor: sayı zaten elde, eksik olan yalnızca kimlerin başvurduğu.
    } finally {
      _pendingApplicantRequests.remove(jobId);
    }

    // Bu arada liste yenilendiyse ilan yer değiştirmiş ya da düşmüş olabilir.
    final current = _jobPosts.indexWhere((post) => post.job.id == jobId);
    if (current == -1) return;

    _jobPosts = [..._jobPosts];
    _jobPosts[current] = _jobPosts[current].copyWith(
      applications: applicants,
      applicantsLoaded: true,
    );
    notifyListeners();
  }

  /// Yeni ilan açar. Başarılıysa liste yenilenir ve `true` döner.
  Future<bool> createJobPost(CreateJobRequest request, {String? companyId}) {
    return _mutate(() => _service.createJob(request, companyId: companyId));
  }

  /// İlanı başvuruya kapatır; ilan "Geçmiş" sekmesine geçer.
  Future<bool> closePost(String jobId) {
    return _mutate(() => _service.closeJob(jobId));
  }

  /// İlanı iptal eder; başvuranlara bildirim gider.
  ///
  /// Devam eden bir atama varsa sunucu reddediyor ve mesajı [errorMessage]'a
  /// düşüyor — çağıran tarafın onu göstermesi gerekiyor.
  Future<bool> cancelPost(String jobId) {
    return _mutate(() => _service.cancelJob(jobId));
  }

  /// İlan listesini değiştiren işlemlerin ortak sarmalayıcısı.
  Future<bool> _mutate(Future<void> Function() call) async {
    _errorMessage = null;

    try {
      await call();
      await load(force: true);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return false;
    }
  }

  /// Başvuruyu kabul eder.
  ///
  /// Sunucuda bir atama oluşuyor ve çalışanın onayı bekleniyor; ilan
  /// kendiliğinden kapanmıyor, o yüzden liste olduğu gibi yenileniyor.
  ///
  /// [jobId] yalnızca yanıt sonrası o ilanın başvuranlarını tazelemek için;
  /// sunucu kabul/ret'i başvuru kimliğiyle alıyor.
  Future<bool> approveApplicant({
    required String jobId,
    required String applicationId,
  }) {
    return _respond(jobId, () => _service.acceptApplication(applicationId));
  }

  /// Başvuruyu reddeder. [reason] çalışanın gördüğü gerekçe.
  Future<bool> rejectApplicant({
    required String jobId,
    required String applicationId,
    String? reason,
  }) {
    return _respond(
      jobId,
      () => _service.rejectApplication(applicationId, reason: reason),
    );
  }

  Future<bool> _respond(String jobId, Future<void> Function() call) async {
    _errorMessage = null;

    try {
      await call();
      // İlanın durumu da değişmiş olabilir; liste ve o ilanın başvuranları
      // birlikte tazeleniyor.
      await load(force: true);
      await ensureApplicants(jobId, force: true);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return false;
    }
  }

  /// Kimliğine göre tek ilan; liste henüz gelmediyse `null`.
  BJobPost? getPostByJobId(String jobId) {
    for (final post in _jobPosts) {
      if (post.job.id == jobId) return post;
    }
    return null;
  }

  /// Çıkışta önceki işverenin ilanları kalmasın.
  void clear() {
    _jobPosts = const [];
    _pendingApplicantRequests.clear();
    _errorMessage = null;
    _hasLoaded = false;
    notifyListeners();
  }
}
