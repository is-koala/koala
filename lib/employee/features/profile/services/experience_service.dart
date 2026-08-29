import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/auth/models/experience.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Kullanıcının iş deneyimleri.
///
/// Okuma için ayrı bir çağrı yok: liste `/users/me` yanıtında geliyor ve
/// `UserProvider` üzerinden okunuyor. Burası yalnızca yazma tarafı; her
/// değişiklikten sonra çağıran taraf `/users/me`'yi tazeliyor.
class ExperienceService {
  ExperienceService._(this._apiClient);

  static final ExperienceService _instance = ExperienceService._(ApiClient());

  factory ExperienceService() => _instance;

  @visibleForTesting
  factory ExperienceService.withClient(ApiClient apiClient) {
    return ExperienceService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Deneyim ekler.
  ///
  /// [title] ve [startDate] zorunlu. Başlangıç gelecekte olamıyor, bitiş
  /// başlangıçtan önce olamıyor; ikisi de `400`.
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

  /// Deneyimi günceller.
  ///
  /// Uç `PUT` — kısmi güncelleme değil, kaydın tamamı gönderiliyor. Bu yüzden
  /// form açılırken mevcut değerlerle dolduruluyor; boş bırakılan alan
  /// temizlenmiş sayılıyor.
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

  /// Deneyimi siler. Başkasının kaydı `404`.
  Future<void> delete(String experienceId) {
    return _apiClient.deleteWithoutData(
      ApiPaths.currentUserExperience(experienceId),
    );
  }

  /// Gövde. Sunucu tarihi `LocalDate` bekliyor, saat kısmı gönderilmiyor.
  ///
  /// Boş metinler `null` olarak gidiyor: `""` göndermek alanı boş bir metne
  /// eşitlerdi, oysa kastedilen "yok".
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
      'startDate': _asLocalDate(startDate),
      'endDate': endDate == null ? null : _asLocalDate(endDate),
      'description': _trimmed(description),
    };
  }

  static String? _trimmed(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// `yyyy-MM-dd`. `toIso8601String` saat de yazıyor ve sunucunun
  /// `LocalDate` çözümleyicisi onu reddediyor.
  static String _asLocalDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
