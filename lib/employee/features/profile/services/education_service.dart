import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/auth/models/education.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Öğrenim kayıtlarının yazma uçları; okuma `/users/me`'den, çağıran her
/// değişiklikten sonra tazeler.
class EducationService {
  EducationService._(this._apiClient);

  static final EducationService _instance = EducationService._(ApiClient());

  factory EducationService() => _instance;

  @visibleForTesting
  factory EducationService.withClient(ApiClient apiClient) {
    return EducationService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Not 0–4 arası, bitiş başlangıçtan önce olamaz; ikisi de `400`.
  Future<Education> create({
    required String universityId,
    required String facultyId,
    required String departmentId,
    required GradeType type,
    required DateTime startDate,
    double? gpa,
    DateTime? endDate,
  }) {
    return _apiClient.post<Education>(
      ApiPaths.currentUserEducations,
      body: _body(
        universityId: universityId,
        facultyId: facultyId,
        departmentId: departmentId,
        type: type,
        startDate: startDate,
        gpa: gpa,
        endDate: endDate,
      ),
      parse: (data) => Education.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Uç `PUT`: kaydın tamamı gönderilir.
  Future<Education> update({
    required String educationId,
    required String universityId,
    required String facultyId,
    required String departmentId,
    required GradeType type,
    required DateTime startDate,
    double? gpa,
    DateTime? endDate,
  }) {
    return _apiClient.put<Education>(
      ApiPaths.currentUserEducation(educationId),
      body: _body(
        universityId: universityId,
        facultyId: facultyId,
        departmentId: departmentId,
        type: type,
        startDate: startDate,
        gpa: gpa,
        endDate: endDate,
      ),
      parse: (data) => Education.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Başkasının kaydı `404`.
  Future<void> delete(String educationId) {
    return _apiClient.deleteWithoutData(
      ApiPaths.currentUserEducation(educationId),
    );
  }

  /// Tarih `LocalDate`. [gpa] yoksa `0` gider: alan `null` kabul etmiyor,
  /// sunucu 0'ı "girilmemiş" okuyor.
  Map<String, dynamic> _body({
    required String universityId,
    required String facultyId,
    required String departmentId,
    required GradeType type,
    required DateTime startDate,
    double? gpa,
    DateTime? endDate,
  }) {
    return {
      'universityId': universityId,
      'facultyId': facultyId,
      'departmentId': departmentId,
      'type': type.code,
      'gpa': gpa ?? 0,
      'startDate': startDate.asLocalDate,
      'endDate': endDate?.asLocalDate,
    };
  }
}
