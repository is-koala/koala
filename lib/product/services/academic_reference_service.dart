import 'package:flutter/foundation.dart';
import 'package:koala/product/models/academic_reference.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Üniversite / fakülte / bölüm listelerinin kaynağı (`/reference/**`).
///
/// Üç uç da kimlik doğrulama istemiyor (`@SecurityRequirements`), yani
/// giriş yapılmadan da okunabiliyor.
///
/// Listeler nadiren değiştiği için bir kez çekilip bellekte tutuluyor;
/// fakülte ve bölüm de üstündeki kayda göre ayrı ayrı önbellekleniyor.
class AcademicReferenceService {
  AcademicReferenceService._(this._apiClient);

  static final AcademicReferenceService _instance = AcademicReferenceService._(
    ApiClient(),
  );

  factory AcademicReferenceService() => _instance;

  @visibleForTesting
  factory AcademicReferenceService.withClient(ApiClient apiClient) {
    return AcademicReferenceService._(apiClient);
  }

  final ApiClient _apiClient;

  List<AcademicReference>? _universities;
  final Map<String, List<AcademicReference>> _faculties = {};
  final Map<String, List<AcademicReference>> _departments = {};

  Future<List<AcademicReference>> fetchUniversities() async {
    return _universities ??= await _fetchList(ApiPaths.universities);
  }

  Future<List<AcademicReference>> fetchFaculties(String universityId) async {
    return _faculties[universityId] ??= await _fetchList(
      ApiPaths.universityFaculties(universityId),
    );
  }

  Future<List<AcademicReference>> fetchDepartments(String facultyId) async {
    return _departments[facultyId] ??= await _fetchList(
      ApiPaths.facultyDepartments(facultyId),
    );
  }

  Future<List<AcademicReference>> _fetchList(String path) {
    return _apiClient.get<List<AcademicReference>>(
      path,
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(AcademicReference.fromJson)
                .toList()
          : const [],
    );
  }

  /// Önbelleği boşaltır. Yalnızca testler için; listeler oturum boyunca
  /// değişmiyor.
  @visibleForTesting
  void clearCache() {
    _universities = null;
    _faculties.clear();
    _departments.clear();
  }
}
