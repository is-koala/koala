import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/auth/models/education.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Kullanıcının öğrenim kayıtları.
///
/// Okuma için ayrı bir çağrı yok: liste `/users/me` yanıtında geliyor ve
/// `UserProvider` üzerinden okunuyor. Burası yalnızca yazma tarafı; her
/// değişiklikten sonra çağıran taraf `/users/me`'yi tazeliyor.
class EducationService {
  EducationService._(this._apiClient);

  static final EducationService _instance = EducationService._(ApiClient());

  factory EducationService() => _instance;

  @visibleForTesting
  factory EducationService.withClient(ApiClient apiClient) {
    return EducationService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Öğrenim kaydı ekler.
  ///
  /// Üniversite, fakülte, bölüm, kademe ve başlangıç zorunlu. Not
  /// ortalaması 0 ile 4 arasında olmalı, bitiş başlangıçtan önce olamaz;
  /// ikisi de `400`.
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

  /// Kaydı günceller.
  ///
  /// Uç `PUT` — kısmi güncelleme değil, kaydın tamamı gönderiliyor. Form da
  /// bu yüzden mevcut değerlerle açılıyor.
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

  /// Kaydı siler. Başkasının kaydı `404`.
  Future<void> delete(String educationId) {
    return _apiClient.deleteWithoutData(
      ApiPaths.currentUserEducation(educationId),
    );
  }

  /// Gövde. Sunucu tarihleri `LocalDate` bekliyor, saat kısmı
  /// gönderilmiyor.
  ///
  /// [gpa] verilmezse `0` gidiyor: alan `double` ve `null` kabul etmiyor,
  /// sunucu da 0'ı "girilmemiş" olarak okuyor.
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
      'startDate': _asLocalDate(startDate),
      'endDate': endDate == null ? null : _asLocalDate(endDate),
    };
  }

  /// `yyyy-MM-dd`. `toIso8601String` saat de yazıyor ve sunucunun
  /// `LocalDate` çözümleyicisi onu reddediyor.
  static String _asLocalDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
