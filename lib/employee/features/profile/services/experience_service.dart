import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/auth/models/experience.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Deneyimlerin yazma uçları; okuma `/users/me`'den.
class ExperienceService {
  ExperienceService._(this._apiClient);

  static final ExperienceService _instance = ExperienceService._(ApiClient());

  factory ExperienceService() => _instance;

  @visibleForTesting
  factory ExperienceService.withClient(ApiClient apiClient) {
    return ExperienceService._(apiClient);
  }

  final ApiClient _apiClient;

  /// [title] ve [startDate] zorunlu; başlangıç gelecekte, bitiş başlangıçtan
  /// önce olamaz (`400`).
  Future<Experience> create({
    required String title,
    required DateTime startDate,
    String? companyName,
    EmploymentType? employmentType,
    String? cityName,
    DateTime? endDate,
    String? description,
  }) {
    return _apiClient.post<Experience>(
      ApiPaths.currentUserExperiences,
      body: _body(
        title: title,
        startDate: startDate,
        companyName: companyName,
        employmentType: employmentType,
        cityName: cityName,
        endDate: endDate,
        description: description,
      ),
      parse: (data) => Experience.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Uç `PUT`: kaydın tamamı gönderilir, boş alan temizlenmiş sayılır.
  Future<Experience> update({
    required String experienceId,
    required String title,
    required DateTime startDate,
    String? companyName,
    EmploymentType? employmentType,
    String? cityName,
    DateTime? endDate,
    String? description,
  }) {
    return _apiClient.put<Experience>(
      ApiPaths.currentUserExperience(experienceId),
      body: _body(
        title: title,
        startDate: startDate,
        companyName: companyName,
        employmentType: employmentType,
        cityName: cityName,
        endDate: endDate,
        description: description,
      ),
      parse: (data) => Experience.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Başkasının kaydı `404`.
  Future<void> delete(String experienceId) {
    return _apiClient.deleteWithoutData(
      ApiPaths.currentUserExperience(experienceId),
    );
  }

  /// Boş metin `null` gider: kastedilen "yok", `""` değil.
  Map<String, dynamic> _body({
    required String title,
    required DateTime startDate,
    String? companyName,
    EmploymentType? employmentType,
    String? cityName,
    DateTime? endDate,
    String? description,
  }) {
    return {
      'title': title,
      'companyName': _trimmed(companyName),
      'employmentType': employmentType?.code,
      'cityName': _trimmed(cityName),
      'startDate': startDate.asLocalDate,
      'endDate': endDate?.asLocalDate,
      'description': _trimmed(description),
    };
  }

  static String? _trimmed(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
