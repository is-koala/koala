import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/services/saved_jobs_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Kaydedilen ilanlar.
///
/// Kaydet butonu iyimser çalışıyor: dokunulduğu anda ikon değişiyor, istek
/// arkada gidiyor. Sunucu reddederse değişiklik geri alınıp hata mesajı
/// yazılıyor — aksi hâlde kullanıcı her kaydetmede bir tur beklerdi.
class SavedJobsProvider extends ChangeNotifier {
  SavedJobsProvider({SavedJobsService? service})
    : _service = service ?? SavedJobsService();

  final SavedJobsService _service;

  final List<Job> _savedJobs = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  List<Job> get savedJobs => List.unmodifiable(_savedJobs);

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  /// Son işlemin hata mesajı. Bir sonraki işlemde temizleniyor.
  String? get errorMessage => _errorMessage;

  bool isSaved(String jobId) {
    return _savedJobs.any((job) => job.id == jobId);
  }

  /// Kayıtlı ilanları çeker.
  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force && _errorMessage == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final jobs = await _service.fetchSavedJobs();
      _savedJobs
        ..clear()
        ..addAll(jobs);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  /// İlanı kaydeder ya da kaydı kaldırır.
  ///
  /// Başarılıysa `true` döner. Başarısızsa liste eski hâline dönüyor ve mesaj
  /// [errorMessage]'a düşüyor.
  Future<bool> toggleSave(Job job) async {
    final wasSaved = isSaved(job.id);
    _errorMessage = null;

    // Önce arayüz: ikon dokunur dokunmaz değişsin.
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
      return true;
    } on ApiException catch (error) {
      // Geri al: sunucu kabul etmediyse arayüz de göstermemeli.
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

  /// Kaydı kaldırır. Kaydedilenler listesindeki çöp kutusu butonu bunu
  /// çağırıyor; ilan zaten elde olduğu için ayrıca aramaya gerek yok.
  Future<bool> removeJob(String jobId) async {
    final index = _savedJobs.indexWhere((job) => job.id == jobId);
    if (index == -1) return false;

    return toggleSave(_savedJobs[index]);
  }

  /// Çıkışta önceki kullanıcının kayıtları kalmasın.
  void clear() {
    _savedJobs.clear();
    _errorMessage = null;
    _hasLoaded = false;
    notifyListeners();
  }
}
