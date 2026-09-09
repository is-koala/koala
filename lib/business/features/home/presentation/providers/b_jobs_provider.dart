import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/b_job_post.dart';
import 'package:koala/business/features/home/models/create_job_request.dart';
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
  int _nextLoadRequestId = 0;
  int? _latestLoadRequestId;

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
    if (_isLoading && !force) return;
    if (_hasLoaded && !force && _errorMessage == null) return;

    final requestId = ++_nextLoadRequestId;
    _latestLoadRequestId = requestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _service.fetchMyJobs();
      if (_latestLoadRequestId != requestId) return;

      // Başvuran isteği liste isteğinden sonra tamamlanmış olabilir. Bir
      // liste yanıtı, istek başlarken alınmış eski snapshot'ı değil tam
      // yanıt anındaki başvuran durumunu yeni ilan özetiyle birleştirir.
      final currentPosts = {for (final post in _jobPosts) post.job.id: post};
      _jobPosts = [
        for (final job in page.jobs)
          currentPosts[job.id]?.withJob(job) ?? BJobPost(job: job),
      ];
      final retainedJobIds = {for (final post in _jobPosts) post.job.id};
      _pendingApplicantRequests.removeWhere(
        (jobId, _) => !retainedJobIds.contains(jobId),
      );
    } on ApiException catch (error) {
      if (_latestLoadRequestId != requestId) return;
      _errorMessage = error.message;
    } finally {
      if (_latestLoadRequestId == requestId) {
        _isLoading = false;
        _hasLoaded = true;
        notifyListeners();
      }
    }
  }

  /// İlan başına güncel başvuru isteği. Değer, eski yanıtların yeni bir
  /// tekrar deneme sonucunu ezmesini önleyen istek kimliğidir.
  final Map<String, int> _pendingApplicantRequests = {};
  int _nextApplicantRequestId = 0;

  String? applicantErrorFor(String jobId) =>
      getPostByJobId(jobId)?.applicantsError;

  /// Bir ilanın başvuranlarını, daha önce çekilmediyse çeker.
  ///
  /// Aynı ilan için ikinci kez çağrılmak zararsız: elde veri varsa ağa
  /// çıkmıyor. Ekranlar bunu ihtiyaç duydukları anda çağırıyor — ilan
  /// listesindeki sayı ilanla birlikte geldiği için liste bu isteği hiç
  /// atmıyor.
  ///
  /// Başvurular alınamazsa eldeki liste korunur ve ilan bazındaki hata
  /// çağıran ekranın tekrar deneme sunabilmesi için ayrıca tutulur.
  Future<void> ensureApplicants(String jobId, {bool force = false}) async {
    final index = _jobPosts.indexWhere((post) => post.job.id == jobId);
    if (index == -1) return;
    if (_jobPosts[index].applicantsLoaded && !force) return;
    if (_jobPosts[index].applicantsError != null && !force) return;
    if (_pendingApplicantRequests.containsKey(jobId) && !force) return;

    final requestId = ++_nextApplicantRequestId;
    _pendingApplicantRequests[jobId] = requestId;

    _updatePost(jobId, (post) => post.startApplicantLoad());
    notifyListeners();

    try {
      final applicants = await _service.fetchApplicants(jobId);
      if (_pendingApplicantRequests[jobId] != requestId) return;

      // Bu arada liste yenilendiyse ilan yer değiştirmiş ya da düşmüş olabilir.
      _updatePost(jobId, (post) => post.completeApplicantLoad(applicants));
    } on ApiException catch (error) {
      if (_pendingApplicantRequests[jobId] != requestId) return;
      _updatePost(jobId, (post) => post.failApplicantLoad(error.message));
    } finally {
      if (_pendingApplicantRequests[jobId] == requestId) {
        _pendingApplicantRequests.remove(jobId);
        notifyListeners();
      }
    }
  }

  void _updatePost(String jobId, BJobPost Function(BJobPost post) update) {
    final index = _jobPosts.indexWhere((post) => post.job.id == jobId);
    if (index == -1) return;
    _jobPosts = [..._jobPosts];
    _jobPosts[index] = update(_jobPosts[index]);
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
    _latestLoadRequestId = null;
    _isLoading = false;
    _pendingApplicantRequests.clear();
    _errorMessage = null;
    _hasLoaded = false;
    notifyListeners();
  }
}
