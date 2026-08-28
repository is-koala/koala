import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/b_job_post.dart';
import 'package:koala/business/features/home/models/create_job_request.dart';
import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// İşverenin ilanları ve o ilanlara gelen başvurular.
///
/// Veri iki uçtan geliyor ve tek listede birleşiyor:
/// - `GET /users/me/jobs` → ilanların özeti,
/// - `GET /jobs/{jobId}/applications` → her ilanın başvuruları.
///
/// İkincisi ilan başına ayrı bir istek: liste ucu başvuru sayısını
/// döndürmüyor. İstekler paralel gidiyor ama yine de N+1.
/// TODO(backend): `JobSummaryDto`'ya `applicationCount` eklenirse liste tek
/// istekle çizilebilir; başvuranların kendisi ancak detay ekranında gerekiyor.
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

  /// Aktif ilanlara gelen, henüz yanıtlanmamış başvuruların toplamı.
  int get pendingApplicantCount =>
      activePosts.fold<int>(0, (sum, post) => sum + post.applicants.length);

  /// İlanları ve başvurularını çeker.
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

      // İlanlar geldiği anda çizilebilsin; başvurular arkadan dolsun.
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();

      await _loadApplicants();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  /// Her ilanın başvurularını paralel çeker.
  ///
  /// Tek bir ilanın başvuruları alınamazsa liste bütünüyle hataya düşmüyor:
  /// o ilan başvurusuz görünüyor, diğerleri çiziliyor. Ekranı kaplayan bir
  /// hata, elde duran ilanları da gizlerdi.
  Future<void> _loadApplicants() async {
    final posts = _jobPosts;
    if (posts.isEmpty) return;

    final results = await Future.wait([
      for (final post in posts) _applicantsOf(post.job.id),
    ]);

    // Bu arada yenileme yapıldıysa eski sonuçlar yazılmamalı.
    if (!identical(_jobPosts, posts)) return;

    _jobPosts = [
      for (var i = 0; i < posts.length; i++)
        posts[i].copyWith(applications: results[i], applicantsLoaded: true),
    ];
    notifyListeners();
  }

  Future<List<JobApplicant>> _applicantsOf(String jobId) async {
    try {
      return await _service.fetchApplicants(jobId);
    } on ApiException {
      return const [];
    }
  }

  /// Yeni ilan açar. Başarılıysa liste yenilenir ve `true` döner.
  Future<bool> createJobPost(
    CreateJobRequest request, {
    String? companyId,
  }) async {
    _errorMessage = null;

    try {
      await _service.createJob(request, companyId: companyId);
      await load(force: true);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return false;
    }
  }

  /// İlanı başvuruya kapatır; ilan "Geçmiş" sekmesine geçer.
  Future<bool> closePost(String jobId) async {
    _errorMessage = null;

    try {
      await _service.closeJob(jobId);
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
  Future<bool> approveApplicant(String applicationId) {
    return _respond(() => _service.acceptApplication(applicationId));
  }

  /// Başvuruyu reddeder. [reason] çalışanın gördüğü gerekçe.
  Future<bool> rejectApplicant(String applicationId, {String? reason}) {
    return _respond(
      () => _service.rejectApplication(applicationId, reason: reason),
    );
  }

  Future<bool> _respond(Future<void> Function() call) async {
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
    _errorMessage = null;
    _hasLoaded = false;
    notifyListeners();
  }
}
