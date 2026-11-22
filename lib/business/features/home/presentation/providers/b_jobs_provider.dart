import 'package:material_ui/material_ui.dart';
import 'package:koala/business/features/home/models/b_job_post.dart';
import 'package:koala/business/features/home/models/create_job_request.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// İşverenin ilanları ve başvuruları.
///
/// İlan özeti (sayı dâhil) `GET /users/me/jobs`'tan; başvuranlar ilan ilan
/// [ensureApplicants] ile, gerektiğinde. Liste bu isteği hiç atmıyor.
///
/// **Liste ile yönetilen ilan aynı küme değil:** liste yalnız kullanıcının
/// açtığı ilk sayfayı getiriyor, sunucu ise şirket ilanının başvurularını her
/// yetkiliye açıyor. İlan detayı bunları [adoptJob] ile benimsiyor; benimsenen
/// ilan liste ve sayaçlarda görünmez.
class BJobsProvider extends ChangeNotifier {
  BJobsProvider({EmployerJobService? service})
    : _service = service ?? EmployerJobService();

  final EmployerJobService _service;

  List<BJobPost> _jobPosts = const [];

  /// Benimsenen ilanlar; ayrı, çünkü [load] listeyi baştan kurup bunları
  /// düşürürdü.
  final Map<String, BJobPost> _adoptedPosts = {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  int _nextLoadRequestId = 0;
  int? _latestLoadRequestId;

  /// Çıkıştan sonra dönen istekler yeni oturuma yazmasın.
  int _generation = 0;

  List<BJobPost> get allPosts => List.unmodifiable(_jobPosts);

  List<BJobPost> get activePosts =>
      _jobPosts.where((post) => post.isActive).toList();

  List<BJobPost> get pastPosts =>
      _jobPosts.where((post) => !post.isActive).toList();

  bool get isLoading => _isLoading;

  /// Hata da olsa `true`; tekrar denemek çağıranın kararı.
  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  /// Boş liste arıza değil.
  bool get isEmpty => _hasLoaded && _jobPosts.isEmpty && _errorMessage == null;

  /// Aktif ilanlara gelen toplam; yanıtlanmışlar dâhil.
  int get totalApplicantCount =>
      activePosts.fold<int>(0, (sum, post) => sum + post.job.applicationCount);

  /// İlan listesini çeker; daha önce çekildiyse [force] olmadan ağa çıkmaz.
  Future<void> load({bool force = false}) async {
    if (_isLoading && !force) return;
    if (_hasLoaded && !force && _errorMessage == null) return;

    final generation = _generation;
    final requestId = ++_nextLoadRequestId;
    _latestLoadRequestId = requestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _service.fetchMyJobs();
      if (generation != _generation || _latestLoadRequestId != requestId) {
        return;
      }

      // Başvuran isteği listeden sonra bitmiş olabilir; yanıt anındaki durum
      // birleştirilir.
      final currentPosts = {
        ..._adoptedPosts,
        for (final post in _jobPosts) post.job.id: post,
      };
      _jobPosts = [
        for (final job in page.jobs)
          currentPosts[job.id]?.withJob(job) ?? BJobPost(job: job),
      ];
      // Liste ilanı kendisi getiriyorsa benimsenmiş kopya ikinci kayıt
      // kalmasın.
      final listedJobIds = {for (final post in _jobPosts) post.job.id};
      _adoptedPosts.removeWhere((jobId, _) => listedJobIds.contains(jobId));
      final retainedJobIds = {...listedJobIds, ..._adoptedPosts.keys};
      _pendingApplicantRequests.removeWhere(
        (jobId, _) => !retainedJobIds.contains(jobId),
      );
    } on ApiException catch (error) {
      if (generation != _generation || _latestLoadRequestId != requestId) {
        return;
      }
      _errorMessage = error.message;
    } finally {
      if (generation == _generation && _latestLoadRequestId == requestId) {
        _isLoading = false;
        _hasLoaded = true;
        notifyListeners();
      }
    }
  }

  /// Eski yanıt yeni denemenin sonucunu ezmesin diye istek kimliği.
  final Map<String, int> _pendingApplicantRequests = {};
  int _nextApplicantRequestId = 0;

  String? applicantErrorFor(String jobId) =>
      getPostByJobId(jobId)?.applicantsError;

  /// Başvuranları gerekiyorsa çeker; ikinci çağrı zararsız. Alınamazsa eldeki
  /// liste korunur, hata ilan bazında tutulur.
  Future<void> ensureApplicants(String jobId, {bool force = false}) async {
    final post = getPostByJobId(jobId);
    if (post == null) return;
    if (post.applicantsLoaded && !force) return;
    if (post.applicantsError != null && !force) return;
    if (_pendingApplicantRequests.containsKey(jobId) && !force) return;

    final generation = _generation;
    final requestId = ++_nextApplicantRequestId;
    _pendingApplicantRequests[jobId] = requestId;

    _updatePost(jobId, (post) => post.startApplicantLoad());
    notifyListeners();

    try {
      final applicants = await _service.fetchApplicants(jobId);
      if (generation != _generation ||
          _pendingApplicantRequests[jobId] != requestId) {
        return;
      }

      // Bu arada liste yenilenmiş olabilir.
      _updatePost(jobId, (post) => post.completeApplicantLoad(applicants));
    } on ApiException catch (error) {
      if (generation != _generation ||
          _pendingApplicantRequests[jobId] != requestId) {
        return;
      }
      _updatePost(jobId, (post) => post.failApplicantLoad(error.message));
    } finally {
      if (generation == _generation &&
          _pendingApplicantRequests[jobId] == requestId) {
        _pendingApplicantRequests.remove(jobId);
        notifyListeners();
      }
    }
  }

  void _updatePost(String jobId, BJobPost Function(BJobPost post) update) {
    final index = _jobPosts.indexWhere((post) => post.job.id == jobId);
    if (index != -1) {
      _jobPosts = [..._jobPosts];
      _jobPosts[index] = update(_jobPosts[index]);
      return;
    }

    final adopted = _adoptedPosts[jobId];
    if (adopted != null) _adoptedPosts[jobId] = update(adopted);
  }

  /// Listede olmayan ilanı benimser; benimsendiyse `true`. Şirket ilanıysa ya
  /// da ilanı [viewerId] açtıysa benimsenir; başkasının bireysel ilanının
  /// başvurularını sunucu zaten vermez. Yeniden benimsemede başvuranlar
  /// korunur.
  bool adoptJob(JobDetail detail, {required String? viewerId}) {
    if (_jobPosts.any((post) => post.job.id == detail.id)) return false;

    final isCompanyJob = detail.employerType == JobEmployerType.company;
    final openedByViewer = viewerId != null && detail.creator?.id == viewerId;
    if (!isCompanyJob && !openedByViewer) return false;

    final summary = detail.toSummary();
    _adoptedPosts[detail.id] =
        _adoptedPosts[detail.id]?.withJob(summary) ?? BJobPost(job: summary);
    notifyListeners();
    return true;
  }

  /// Başarıda açılan ilan döner; ulaşım planı ilanın kimliğiyle ayrı yazılıyor
  /// (#197).
  Future<JobDetail?> createJobPost(
    CreateJobRequest request, {
    String? companyId,
  }) async {
    JobDetail? created;
    final ok = await _mutate(() async {
      created = await _service.createJob(request, companyId: companyId);
    });
    return ok ? created : null;
  }

  Future<bool> closePost(String jobId) {
    return _mutate(() => _service.closeJob(jobId));
  }

  /// Devam eden atama varsa sunucu reddeder; mesaj [errorMessage]'da.
  Future<bool> cancelPost(String jobId) {
    return _mutate(() => _service.cancelJob(jobId));
  }

  Future<bool> _mutate(Future<void> Function() call) async {
    final generation = _generation;
    _errorMessage = null;

    try {
      await call();
      if (generation != _generation) return false;
      await load(force: true);
      return generation == _generation;
    } on ApiException catch (error) {
      if (generation == _generation) {
        _errorMessage = error.message;
        notifyListeners();
      }
      return false;
    }
  }

  /// Kabul bir atama açar ve çalışanın onayını bekler; ilan kapanmaz. [jobId]
  /// yalnız başvuranları tazelemek için.
  Future<bool> approveApplicant({
    required String jobId,
    required String applicationId,
  }) {
    return _respond(jobId, () => _service.acceptApplication(applicationId));
  }

  /// [reason] çalışanın gördüğü gerekçe.
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
    final generation = _generation;
    _errorMessage = null;

    try {
      await call();
      if (generation != _generation) return false;
      await load(force: true);
      if (generation != _generation) return false;
      await ensureApplicants(jobId, force: true);
      return generation == _generation;
    } on ApiException catch (error) {
      if (generation == _generation) {
        _errorMessage = error.message;
        notifyListeners();
      }
      return false;
    }
  }

  /// Listedeki kayıt benimsenmiş kopyadan önce gelir.
  BJobPost? getPostByJobId(String jobId) {
    for (final post in _jobPosts) {
      if (post.job.id == jobId) return post;
    }
    return _adoptedPosts[jobId];
  }

  void clear() {
    _generation++;
    _jobPosts = const [];
    _adoptedPosts.clear();
    _latestLoadRequestId = null;
    _isLoading = false;
    _pendingApplicantRequests.clear();
    _errorMessage = null;
    _hasLoaded = false;
    notifyListeners();
  }
}
