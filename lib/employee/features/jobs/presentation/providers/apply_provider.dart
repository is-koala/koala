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

  List<JobApplication> get applications => List.unmodifiable(_applications);

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  /// Başvuruların "İşlerim" ekranındaki karşılığı.
  ///
  /// Ekran hâlâ [MyJob] üzerinden çiziliyor; kabul edilmiş başvurular bir
  /// atamaya dönüştüğü için buradaki karşılıkları yalnızca "başvuru bekliyor"
  /// ve "reddedildi" durumları.
  List<MyJob> get appliedJobs =>
      _applications.map(_toMyJob).toList(growable: false);

  bool hasApplied(String jobId) {
    return _applications.any((application) => application.job.id == jobId);
  }

  /// Başvuruları sunucudan çeker.
  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force && _errorMessage == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _service.fetchMyApplications();
      _applications
        ..clear()
        ..addAll(page.applications);
    } on ApiException catch (error) {
      _errorMessage = error.message;
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
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Çıkışta önceki kullanıcının başvuruları kalmasın.
  void clear() {
    _applications.clear();
    _errorMessage = null;
    _hasLoaded = false;
    notifyListeners();
  }

  static MyJob _toMyJob(JobApplication application) {
    final job = application.job;
    final date = application.applicationDateTime;

    return MyJob(
      id: application.id,
      title: job.title,
      company: job.company ?? 'Bireysel İlan',
      companyId: null,
      description: job.subtitle,
      date: date?.asShortDate ?? '',
      price: job.price,
      // TODO(backend): Reddedilen başvurunun arayüzde karşılığı yok;
      // `MyJobStatus` dört durum taşıyor ve hiçbiri "reddedildi" değil.
      // Şimdilik beklemede gösteriliyor — tasarıma yeni bir durum eklenmeli.
      status: MyJobStatus.pending,
    );
  }
}
