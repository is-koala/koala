import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Kullanıcının başvuruları; başarılı gönderimde dönen kayıt başa eklenir.
class ApplyProvider extends ChangeNotifier {
  ApplyProvider({JobApplicationService? service})
    : _service = service ?? JobApplicationService();

  final JobApplicationService _service;

  final List<JobApplication> _applications = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  /// Başvuru kapısının üç şartı ayrı kodlarla geliyor; ekran koda bakıyor.
  String? _errorCode;

  /// Aynı anda tek geri çekme; satırın düğmesi buna göre kilitlenir.
  String? _withdrawingId;

  /// Çıkıştan sonra dönen istekler yeni oturuma yazmasın.
  int _generation = 0;

  List<JobApplication> get applications => List.unmodifiable(_applications);

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  String? get errorCode => _errorCode;

  String? get withdrawingId => _withdrawingId;

  /// Kabul edilen başvuru atama olduğu için girmiyor ([MyJob.fromApplication]).
  List<MyJob> get appliedJobs =>
      _applications.map(MyJob.fromApplication).nonNulls.toList(growable: false);

  /// Geri çekilmiş başvuru saymaz; sunucu yeniden başvuruya izin veriyor
  /// ([ApplicationStatus.blocksReapplication]).
  bool hasApplied(String jobId) {
    return _applications.any(
      (application) =>
          application.job.id == jobId && application.status.blocksReapplication,
    );
  }

  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force && _errorMessage == null) return;

    final generation = _generation;
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final page = await _service.fetchMyApplications();
      if (generation != _generation) return;
      _applications
        ..clear()
        ..addAll(page.applications);
    } on ApiException catch (error) {
      if (generation == _generation) {
        _errorMessage = error.message;
        _errorCode = error.errorCode;
      }
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        _hasLoaded = true;
        notifyListeners();
      }
    }
  }

  /// Başarılıysa `true`; ikinci başvuruda mesaj [errorMessage]'da.
  Future<bool> applyToJob(Job job, {String? coverLetter}) async {
    if (hasApplied(job.id)) return false;

    final generation = _generation;
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final application = await _service.apply(
        jobId: job.id,
        notes: coverLetter,
      );
      if (generation != _generation) return false;
      _applications.insert(0, application);
      return true;
    } on ApiException catch (error) {
      if (generation == _generation) {
        _errorMessage = error.message;
        _errorCode = error.errorCode;
      }
      return false;
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Geri çeker. **Yalnız durum alınıyor:** dönen `job` `ShortJobDto`; kayıt
  /// yerine konsa satır ₺0'a düşerdi.
  Future<bool> withdraw(String applicationId) async {
    if (_withdrawingId != null) return false;

    final generation = _generation;
    _withdrawingId = applicationId;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final withdrawn = await _service.withdraw(applicationId);
      if (generation != _generation) return false;
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
      // Liste bayat. Tazeleme mesajdan **önce**: [load] hata alanlarını
      // temizliyor.
      if (generation != _generation) return false;
      if (error.type.serverStateMoved) await load(force: true);
      if (generation != _generation) return false;
      _errorMessage = error.message;
      _errorCode = error.errorCode;
      return false;
    } finally {
      if (generation == _generation) {
        _withdrawingId = null;
        notifyListeners();
      }
    }
  }

  void clear() {
    _generation++;
    _applications.clear();
    _isLoading = false;
    _errorMessage = null;
    _errorCode = null;
    _withdrawingId = null;
    _hasLoaded = false;
    notifyListeners();
  }
}
