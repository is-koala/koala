import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/job_alert.dart';
import 'package:koala/employee/features/jobs/services/job_alert_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// İş alarmları ekranının sunucu durumunu ve kullanıcı eylemlerini tutar.
class JobAlertsProvider extends ChangeNotifier {
  JobAlertsProvider({JobAlertService? service})
    : _service = service ?? JobAlertService();

  final JobAlertService _service;
  final List<JobAlert> _alerts = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  List<JobAlert> get alerts => List.unmodifiable(_alerts);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  bool get canCreate => _alerts.length < 10;

  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force && _errorMessage == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final alerts = await _service.fetchAlerts();
      _alerts
        ..clear()
        ..addAll(alerts);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  Future<bool> create(JobAlertDraft draft) async {
    _errorMessage = null;
    if (!canCreate) {
      _errorMessage = 'En fazla 10 iş alarmı oluşturabilirsiniz.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();
    try {
      final alert = await _service.createAlert(draft);
      _alerts.insert(0, alert);
      return true;
    } on JobAlertValidationException catch (error) {
      _errorMessage = error.message;
      return false;
    } on ApiException catch (error) {
      _errorMessage = _messageFor(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> update(String alertId, JobAlertDraft draft) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      final updated = await _service.updateAlert(alertId, draft);
      final index = _alerts.indexWhere((alert) => alert.id == alertId);
      if (index >= 0) _alerts[index] = updated;
      return true;
    } on JobAlertValidationException catch (error) {
      _errorMessage = error.message;
      return false;
    } on ApiException catch (error) {
      _errorMessage = _messageFor(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> delete(String alertId) async {
    final index = _alerts.indexWhere((alert) => alert.id == alertId);
    if (index < 0) return false;

    final removed = _alerts.removeAt(index);
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.deleteAlert(alertId);
      return true;
    } on ApiException catch (error) {
      _alerts.insert(index, removed);
      _errorMessage = _messageFor(error);
      notifyListeners();
      return false;
    }
  }

  String _messageFor(ApiException error) {
    if (error.type == ApiErrorType.conflict) {
      return 'En fazla 10 iş alarmı oluşturabilirsiniz.';
    }
    if (error.type == ApiErrorType.notFound) {
      return 'İş alarmı bulunamadı. Listeyi yenileyip tekrar deneyin.';
    }
    if (error.type == ApiErrorType.validation) {
      return 'Alarm için en az bir geçerli ölçüt seçin.';
    }
    return error.message;
  }

  void clear() {
    _alerts.clear();
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }
}
