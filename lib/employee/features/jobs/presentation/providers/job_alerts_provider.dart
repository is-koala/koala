import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/job_alert.dart';
import 'package:koala/employee/features/jobs/services/job_alert_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// İş alarmları ekranının sunucu durumunu ve kullanıcı eylemlerini tutar.
class JobAlertsProvider extends ChangeNotifier {
  JobAlertsProvider({JobAlertService? service})
    : _service = service ?? JobAlertService();

  final JobAlertService _service;
  static const int maximumAlertCount = 10;

  /// Sunucunun makine tarafından okunabilir hata kodları.
  ///
  /// `KoalaException.deriveErrorCode` bunları mesaj anahtarından türetiyor:
  /// süslü parantezler düşüyor, nokta alt çizgi oluyor, tamamı büyük harfe
  /// çıkıyor. Yani `{job.alert.too.many}` → `JOB_ALERT_TOO_MANY`.
  static const String _quotaExceededCode = 'JOB_ALERT_TOO_MANY';
  static const String _alertNotFoundCode = 'JOB_ALERT_NOT_FOUND';
  static const String _categoryNotFoundCode = 'JOB_ALERT_CATEGORY_NOT_FOUND';
  final List<JobAlert> _alerts = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  int _generation = 0;

  List<JobAlert> get alerts => List.unmodifiable(_alerts);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  bool get canCreate => _alerts.length < maximumAlertCount;

  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force && _errorMessage == null) return;

    final generation = _generation;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final alerts = await _service.fetchAlerts();
      if (generation != _generation) return;
      _alerts
        ..clear()
        ..addAll(alerts);
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

  Future<bool> create(JobAlertDraft draft) async {
    _errorMessage = null;
    if (!canCreate) {
      _errorMessage =
          'En fazla $maximumAlertCount iş alarmı oluşturabilirsiniz.';
      notifyListeners();
      return false;
    }

    return _save(
      draft: draft,
      request: () => _service.createAlert(draft),
      apply: (alert) => _alerts.insert(0, alert),
    );
  }

  Future<bool> update(String alertId, JobAlertDraft draft) async {
    return _save(
      draft: draft,
      request: () => _service.updateAlert(alertId, draft),
      apply: (updated) {
        final index = _alerts.indexWhere((alert) => alert.id == alertId);
        if (index >= 0) _alerts[index] = updated;
      },
    );
  }

  Future<bool> _save({
    required JobAlertDraft draft,
    required Future<JobAlert> Function() request,
    required ValueChanged<JobAlert> apply,
  }) async {
    _errorMessage = null;
    try {
      draft.validate();
    } on JobAlertValidationException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();
    final generation = _generation;
    try {
      final saved = await request();
      if (generation != _generation) return false;
      apply(saved);
      return true;
    } on ApiException catch (error) {
      if (generation == _generation) _errorMessage = _messageFor(error);
      return false;
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> delete(String alertId) async {
    final index = _alerts.indexWhere((alert) => alert.id == alertId);
    if (index < 0) return false;

    final removed = _alerts.removeAt(index);
    final generation = _generation;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.deleteAlert(alertId);
      return generation == _generation;
    } on ApiException catch (error) {
      if (generation == _generation) {
        _alerts.insert(index, removed);
        _errorMessage = _messageFor(error);
        notifyListeners();
      }
      return false;
    }
  }

  /// Sunucunun hatasını ekranda yazacak metne çevirir.
  ///
  /// Yönlendirme `errorCode` ile, durum kodu ya da [ApiErrorType] ile değil.
  /// Sebebi somut: kota aşımını sunucu `ValidationException` ile döndürüyor
  /// (`JobAlertManager:57`), yani ölçüt eksikliğiyle **aynı** HTTP 400 ve
  /// **aynı** `VALIDATION_FAILED` kategorisini taşıyor. Tipe bakan bir dal
  /// ikisini ayıramaz — ayıramıyordu da: kotaya takılan kullanıcıya "en az
  /// bir geçerli ölçüt seçin" yazılıyordu, ve 409 bekleyen dal bu uçlardan
  /// hiç çalışmıyordu çünkü iş alarmı uçlarında 409 atan hiçbir yer yok.
  ///
  /// AGENTS.md kuralı zaten bu: "`ApiException.errorCode` is what routing
  /// keys off, never the message text."
  String _messageFor(ApiException error) {
    switch (error.errorCode) {
      case _quotaExceededCode:
        return 'En fazla $maximumAlertCount iş alarmı oluşturabilirsiniz.';
      case _alertNotFoundCode:
        return 'İş alarmı bulunamadı. Listeyi yenileyip tekrar deneyin.';
      case _categoryNotFoundCode:
        return 'Seçtiğiniz kategori artık yok. Ölçütleri güncelleyip tekrar deneyin.';
    }

    // Alan bazlı doğrulama hatalarının hepsi **tek** koda düşüyor: boş
    // `errorCode`'u `ErrorResult:20` kategori adıyla dolduruyor, yani ad,
    // şehir, ilçe, ücret ve ölçüt hataları ayrımsız `VALIDATION_FAILED`
    // taşıyor (`ErrorContractIT:137` bunu sabitliyor). Onları birbirinden
    // ayıran `details`: sunucu her alan için çözülmüş Türkçe metni orada
    // gönderiyor (`Accept-Language: tr`), o yüzden burada kopyasını tutmak
    // yerine olduğu gibi gösteriliyor.
    if (error.fieldErrors.isNotEmpty) return error.fieldErrors.first.message;

    // Tanımadığımız bir hata: sunucunun kendi metni zaten Türkçe,
    // uydurmaktan iyi.
    return error.message;
  }

  void clear() {
    _generation++;
    _alerts.clear();
    _isLoading = false;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }
}
