import 'dart:math' as math;

import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';
import 'package:koala/product/models/copy_with.dart';
import 'package:koala/product/utils/coordinate_precision.dart';

/// Sıralama seçenekleri. Sunucu **beyaz liste** uyguluyor (listede olmayan
/// `400`); seçenekler yalnız buradan üretiliyor.
enum JobSortOption {
  newest('createdAt', _descending, 'En yeni'),
  nearest('distance', _ascending, 'En yakın'),
  salaryAsc('salary', _ascending, 'Ücret (artan)'),
  salaryDesc('salary', _descending, 'Ücret (azalan)'),
  startDateAsc('startDateTime', _ascending, 'Başlangıç tarihi'),
  titleAsc('title', _ascending, 'Başlık (A-Z)');

  const JobSortOption(this.field, this.direction, this.label);

  static const String _ascending = 'asc';
  static const String _descending = 'desc';

  final String field;

  final String direction;

  final String label;

  String get parameter => '$field,$direction';

  /// Varsayılansa parametre hiç gönderilmez.
  bool get isDefault => this == JobSortOption.newest;

  /// Konumsuz `400`; izin yokken seçenek kapalı.
  bool get requiresOrigin => this == JobSortOption.nearest;
}

/// Keşfet'in arama ölçütleri; `JobSearchCriteriaDto` ile **birebir**. Liste ve
/// harita aynı tipi kullanıyor ki ayrışmasın. Yarıçap [withRadius] ile kutuya
/// çevriliyor; mesafe sıralaması `lat`/`lng` + `sort=distance,asc`.
class JobSearchQuery {
  const JobSearchQuery({
    this.query,
    this.companyId,
    this.categoryId,
    this.cityId,
    this.districtId,
    this.type,
    this.salaryType,
    this.employerType,
    this.minSalary,
    this.maxSalary,
    this.insuranceRequired,
    this.experienceRequired,
    this.bounds,
    this.latitude,
    this.longitude,
    this.startFrom,
    this.startTo,
    this.sort = JobSortOption.newest,
  });

  /// Başlık, pozisyon, şirket ve konumda aranır.
  final String? query;

  final String? companyId;

  /// Kategorinin kimliği; çizim `code`'a bakıyor.
  final String? categoryId;

  final String? cityId;
  final String? districtId;
  final JobType? type;
  final SalaryType? salaryType;
  final JobEmployerType? employerType;

  /// Açık uçlu; üst sınır yoksa [maxSalary] boş.
  final double? minSalary;
  final double? maxSalary;

  /// `null` "süzme"; `false` sigortasızları süzer.
  final bool? insuranceRequired;
  final bool? experienceRequired;

  /// Dört alan tek tipte: "üçü dolu biri boş" gibi gönderilemeyecek durum
  /// temsil edilemesin.
  final JobMapBounds? bounds;

  /// İkisi birlikte `lat`/`lng`; kartın `distanceKm`'si yalnız bunlarla dolar.
  final double? latitude;
  final double? longitude;

  final DateTime? startFrom;
  final DateTime? startTo;

  final JobSortOption sort;

  bool get hasOrigin => latitude != null && longitude != null;

  bool get hasQuery => query != null && query!.trim().isNotEmpty;

  /// Metin ve sıralama dışında ölçüt var mı; boş sonuç ekranı "hiç ilan yok"
  /// ile "süzgece uyan yok"u buna göre ayırıyor.
  bool get hasFilters =>
      companyId != null ||
      categoryId != null ||
      cityId != null ||
      districtId != null ||
      type != null ||
      salaryType != null ||
      employerType != null ||
      minSalary != null ||
      maxSalary != null ||
      insuranceRequired != null ||
      experienceRequired != null ||
      hasBounds ||
      hasStartWindow;

  bool get hasBounds => bounds != null;

  /// Yalnız ikisi doluysa istekte görünür.
  bool get hasStartWindow => startFrom != null && startTo != null;

  /// Seçilmemiş süzgeç istekte görünmez.
  Map<String, dynamic> toQueryParameters() {
    return {
      'query': ?(hasQuery ? query!.trim() : null),
      'companyId': ?companyId,
      'categoryId': ?categoryId,
      'cityId': ?cityId,
      'districtId': ?districtId,
      'type': ?type?.code,
      'salaryType': ?salaryType?.code,
      'employerType': ?employerType?.code,
      'minSalary': ?minSalary,
      'maxSalary': ?maxSalary,
      'insuranceRequired': ?insuranceRequired,
      'experienceRequired': ?experienceRequired,
      'minLatitude': ?bounds?.minLatitude,
      'maxLatitude': ?bounds?.maxLatitude,
      'minLongitude': ?bounds?.minLongitude,
      'maxLongitude': ?bounds?.maxLongitude,
      'lat': ?_roundedLatitude,
      'lng': ?_roundedLongitude,
      'startFrom': ?_startFromIso,
      'startTo': ?_startToIso,
      'sort': ?(_sortParameter),
    };
  }

  /// Backend `@Digits(fraction = 6)`.
  double? get _roundedLatitude =>
      hasOrigin ? CoordinatePrecision.round6(latitude!) : null;

  double? get _roundedLongitude =>
      hasOrigin ? CoordinatePrecision.round6(longitude!) : null;

  String? get _startFromIso =>
      hasStartWindow ? startFrom!.toUtc().toIso8601String() : null;

  String? get _startToIso =>
      hasStartWindow ? startTo!.toUtc().toIso8601String() : null;

  /// Konumsuz `400` olacağı için parametre düşer.
  String? get _sortParameter {
    if (sort.isDefault) return null;
    if (sort.requiresOrigin && !hasOrigin) return null;
    return sort.parameter;
  }

  /// `null` geçmek **temizler**, hiç geçmemek bırakır ([CopyWith]).
  JobSearchQuery copyWith({
    Object? query = CopyWith.unset,
    Object? companyId = CopyWith.unset,
    Object? categoryId = CopyWith.unset,
    Object? cityId = CopyWith.unset,
    Object? districtId = CopyWith.unset,
    Object? type = CopyWith.unset,
    Object? salaryType = CopyWith.unset,
    Object? employerType = CopyWith.unset,
    Object? minSalary = CopyWith.unset,
    Object? maxSalary = CopyWith.unset,
    Object? insuranceRequired = CopyWith.unset,
    Object? experienceRequired = CopyWith.unset,
    Object? bounds = CopyWith.unset,
    Object? latitude = CopyWith.unset,
    Object? longitude = CopyWith.unset,
    Object? startFrom = CopyWith.unset,
    Object? startTo = CopyWith.unset,
    JobSortOption? sort,
  }) {
    return JobSearchQuery(
      query: CopyWith.pick(query, this.query),
      companyId: CopyWith.pick(companyId, this.companyId),
      categoryId: CopyWith.pick(categoryId, this.categoryId),
      cityId: CopyWith.pick(cityId, this.cityId),
      districtId: CopyWith.pick(districtId, this.districtId),
      type: CopyWith.pick(type, this.type),
      salaryType: CopyWith.pick(salaryType, this.salaryType),
      employerType: CopyWith.pick(employerType, this.employerType),
      minSalary: CopyWith.pick(minSalary, this.minSalary),
      maxSalary: CopyWith.pick(maxSalary, this.maxSalary),
      insuranceRequired: CopyWith.pick(
        insuranceRequired,
        this.insuranceRequired,
      ),
      experienceRequired: CopyWith.pick(
        experienceRequired,
        this.experienceRequired,
      ),
      bounds: CopyWith.pick(bounds, this.bounds),
      latitude: CopyWith.pick(latitude, this.latitude),
      longitude: CopyWith.pick(longitude, this.longitude),
      startFrom: CopyWith.pick(startFrom, this.startFrom),
      startTo: CopyWith.pick(startTo, this.startTo),
      sort: sort ?? this.sort,
    );
  }

  /// Yarıçapı sınırlayıcı kutuya çevirir (sunucuda yarıçap yok). Kutu daireden
  /// büyük; köşelerdeki fazlalık sayfalamanın tutarlılığına değiyor.
  JobSearchQuery withRadius({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) {
    final latitudeDelta = radiusKm / _kmPerLatitudeDegree;

    // Boylam kutuplara doğru daralıyor; kosinüs düzeltmesi olmadan kutu dar
    // kalır.
    final longitudeDelta =
        radiusKm /
        (_kmPerLatitudeDegree * math.cos(latitude * math.pi / 180)).abs();

    return copyWith(
      bounds: JobMapBounds(
        minLatitude: latitude - latitudeDelta,
        maxLatitude: latitude + latitudeDelta,
        minLongitude: longitude - longitudeDelta,
        maxLongitude: longitude + longitudeDelta,
      ),
    );
  }

  static const double _kmPerLatitudeDegree = 111.32;
}
