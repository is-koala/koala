import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/services/saved_jobs_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Kaydedilen ilanlar; kaydet iyimser, reddedilirse geri alınır.
class SavedJobsProvider extends ChangeNotifier {
  SavedJobsProvider({SavedJobsService? service})
    : _service = service ?? SavedJobsService();

  final SavedJobsService _service;

  final List<Job> _savedJobs = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  /// Çıkıştan sonra dönen istekler yeni oturuma yazmasın.
  int _generation = 0;

  List<Job> get savedJobs => List.unmodifiable(_savedJobs);

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  bool isSaved(String jobId) {
    return _savedJobs.any((job) => job.id == jobId);
  }

  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force && _errorMessage == null) return;

    final generation = _generation;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final jobs = await _service.fetchSavedJobs();
      if (generation != _generation) return;
      _savedJobs
        ..clear()
        ..addAll(jobs);
    } on ApiException catch (error) {
      if (generation == _generation) _errorMessage = error.message;
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        _hasLoaded = true;
        notifyListeners();
      }
    }
  }

  /// Başarısızsa liste eski hâline döner, mesaj [errorMessage]'da.
  Future<bool> toggleSave(Job job) async {
    final generation = _generation;
    final wasSaved = isSaved(job.id);
    _errorMessage = null;

    if (wasSaved) {
      _savedJobs.removeWhere((saved) => saved.id == job.id);
    } else {
      _savedJobs.insert(0, job);
    }
    notifyListeners();

    try {
      if (wasSaved) {
        await _service.remove(job.id);
      } else {
        await _service.save(job.id);
      }
      return generation == _generation;
    } on ApiException catch (error) {
      if (generation != _generation) return false;
      if (wasSaved) {
        _savedJobs.insert(0, job);
      } else {
        _savedJobs.removeWhere((saved) => saved.id == job.id);
      }
      _errorMessage = error.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeJob(String jobId) async {
    final index = _savedJobs.indexWhere((job) => job.id == jobId);
    if (index == -1) return false;

    return toggleSave(_savedJobs[index]);
  }

  void clear() {
    _generation++;
    _savedJobs.clear();
    _isLoading = false;
    _errorMessage = null;
    _hasLoaded = false;
    notifyListeners();
  }
}
