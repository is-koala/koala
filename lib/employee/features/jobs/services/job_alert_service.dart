import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/jobs/models/job_alert.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Oturum sahibinin iş alarmı kayıtlarının gerçek backend kapısı.
class JobAlertService {
  JobAlertService._(this._apiClient);

  static final JobAlertService _instance = JobAlertService._(ApiClient());

  factory JobAlertService() => _instance;

  @visibleForTesting
  factory JobAlertService.withClient(ApiClient apiClient) {
    return JobAlertService._(apiClient);
  }

  final ApiClient _apiClient;

  Future<List<JobAlert>> fetchAlerts() {
    return _apiClient.get<List<JobAlert>>(
      ApiPaths.currentUserJobAlerts,
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(JobAlert.fromJson)
                .toList()
          : const [],
    );
  }

  Future<JobAlert> createAlert(JobAlertDraft draft) async {
    final body = draft.toRequestBody();
    return _apiClient.post<JobAlert>(
      ApiPaths.currentUserJobAlerts,
      body: body,
      parse: (data) => JobAlert.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<JobAlert> updateAlert(String alertId, JobAlertDraft draft) async {
    final body = draft.toRequestBody();
    return _apiClient.put<JobAlert>(
      ApiPaths.currentUserJobAlert(alertId),
      body: body,
      parse: (data) => JobAlert.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<void> deleteAlert(String alertId) {
    return _apiClient.deleteWithoutData(ApiPaths.currentUserJobAlert(alertId));
  }
}
