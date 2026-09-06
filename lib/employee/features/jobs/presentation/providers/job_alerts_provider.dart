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

  String _messageFor(ApiException error) {
    if (error.type == ApiErrorType.conflict) {
      return 'En fazla $maximumAlertCount iş alarmı oluşturabilirsiniz.';
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
    _generation++;
    _alerts.clear();
    _isLoading = false;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }
}
