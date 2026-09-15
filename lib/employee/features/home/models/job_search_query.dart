import 'dart:math' as math;

import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';
import 'package:koala/product/models/copy_with.dart';
import 'package:koala/product/utils/coordinate_precision.dart';

/// `GET /jobs` sıralama seçenekleri.
///
/// Sunucu sıralamayı **beyaz listeliyor**: listede olmayan bir alan boş sonuç
/// değil, `400` (`PAGE_SORT_FIELD_NOT_ALLOWED`) döndürüyor. Bu yüzden seçenekler
/// elle dize yazılarak değil, yalnızca buradan üretiliyor — enum'a girmeyen bir
/// alan uygulamadan hiç çıkamıyor.
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

  /// Backend'in `SORTABLE_FIELDS` kümesindeki alan adı.
  final String field;

  /// `asc` ya da `desc`.
  final String direction;

  /// Sıralama menüsünde görünen ad.
  final String label;

  /// Spring'in beklediği `sort=<alan>,<yön>` değeri.
  String get parameter => '$field,$direction';

  /// Sunucunun kendi `DEFAULT_SORT`'u mu (`createdAt DESC`).
  ///
  /// Öyleyse parametre hiç gönderilmiyor: varsayılan durumda sorgunun boş
  /// kalması hem isteği kısaltıyor hem de "süzgeç yok" hâlini okunur tutuyor.
  bool get isDefault => this == JobSortOption.newest;

  /// Mesafeye göre sıralama `lat`/`lng` olmadan 400 döner; konum izni yokken
  /// seçenek kapalı çiziliyor.
  bool get requiresOrigin => this == JobSortOption.nearest;
}

/// Keşfet'in sunucuya gönderdiği arama ölçütleri.
///
/// Alanlar backend'deki `JobSearchCriteriaDto` ile **birebir**: uydurma alan
/// yok, sunucuda karşılığı olmayan bir süzgeç buraya girmiyor. Liste ve harita
/// sekmeleri aynı tipi kullanıyor; ayrı iki sorgu arayüzü olsaydı iki sekme
/// zamanla ayrışırdı.
///
/// Yarıçap süzgeci sunucuda yok; [withRadius] onu sınırlayıcı kutuya çevirir.
/// Mesafe sıralaması ayrı: `lat`/`lng` + `sort=distance,asc` (koala-backend#271).
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

  /// Serbest metin araması: başlık, pozisyon, şirket ve konumda aranıyor.
  final String? query;

  /// Şirketin **id**'si (UUID). Aynı adlı şirketlerin ilanlarını ayırır.
  final String? companyId;

  /// Kategorinin **id**'si (UUID), kodu değil. Çizim tarafı `code`'a bakmayı
  /// sürdürüyor: kod addan bağımsız ve değişmez, id ise sorgunun anahtarı.
  final String? categoryId;

  final String? cityId;
  final String? districtId;
  final JobType? type;
  final SalaryType? salaryType;
  final JobEmployerType? employerType;

  /// Ücret aralığı. Sunucuda açık uçlu; üst sınırı olmayan bir seçim
  /// [maxSalary]'yi boş bırakıyor.
  final double? minSalary;
  final double? maxSalary;

  /// `null` "süzme" demek; `false` **sigortasız ilanları** süzer, ikisi aynı
  /// şey değil.
  final bool? insuranceRequired;
  final bool? experienceRequired;

  /// Haritanın görünen alanı.
  ///
  /// Dördü birlikte anlamlı olduğu için tek tip: dört ayrı `double?` "üçü dolu,
  /// biri boş" gibi sunucuya gönderilemeyecek bir durumu temsil edilebilir
  /// kılıyordu ve [JobMapBounds] zaten vardı.
  final JobMapBounds? bounds;

  /// Kullanıcının konumu. İkisi birlikte [toQueryParameters]'ta `lat`/`lng`
  /// olur; kartın `distanceKm`'si yalnız bunlar gidince dolar.
  final double? latitude;
  final double? longitude;

  /// İşin başladığı an penceresi (`Instant`). İkisi birlikte anlamlı.
  final DateTime? startFrom;
  final DateTime? startTo;

  final JobSortOption sort;

  /// Konum hem enlem hem boylam olarak duruyor mu.
  bool get hasOrigin => latitude != null && longitude != null;

  /// Serbest metin araması var mı.
  bool get hasQuery => query != null && query!.trim().isNotEmpty;

  /// Metin araması ve sıralama **dışında** bir ölçüt seçili mi.
  ///
  /// Boş sonuç ekranı "hiç ilan yok" ile "bu süzgece uyan ilan yok"u ayırmak
  /// için buna bakıyor.
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

  /// Sınırlayıcı kutu seçili mi.
  ///
  /// Eskiden dört alanın **herhangi biri** doluysa `true` veriyordu ama doc'u
  /// "dördü de dolu mu" diyordu; tek alanla `true` dönen bir "dördü de" ifadesi
  /// okuyanı yanıltıyordu. Kutu tek bir alan olunca soru da tekilleşti.
  bool get hasBounds => bounds != null;

  /// Başlangıç günü penceresi seçili mi. Ters aralık üretilmiyor: yalnız
  /// ikisi de doluysa istekte görünür.
  bool get hasStartWindow => startFrom != null && startTo != null;

  /// `GET /jobs` sorgu parametreleri. Boş alanlar **konmuyor** — seçilmemiş bir
  /// süzgeç istekte görünmemeli.
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

  /// Altı ondalık: backend `@Digits(fraction = 6)` ile reddediyor.
  double? get _roundedLatitude =>
      hasOrigin ? CoordinatePrecision.round6(latitude!) : null;

  double? get _roundedLongitude =>
      hasOrigin ? CoordinatePrecision.round6(longitude!) : null;

  String? get _startFromIso =>
      hasStartWindow ? startFrom!.toUtc().toIso8601String() : null;

  String? get _startToIso =>
      hasStartWindow ? startTo!.toUtc().toIso8601String() : null;

  /// Mesafe sıralaması konum olmadan 400; o durumda parametre düşer ve
  /// sunucunun varsayılanı kalır.
  String? get _sortParameter {
    if (sort.isDefault) return null;
    if (sort.requiresOrigin && !hasOrigin) return null;
    return sort.parameter;
  }

  /// Alan güncelleyip yeni bir sorgu üretir.
  ///
  /// `null` geçmek alanı **temizler**; hiç geçmemek olduğu gibi bırakır — bkz.
  /// [CopyWith].
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

  /// Bir noktanın çevresindeki [radiusKm] yarıçapı **sınırlayıcı kutuya**
  /// çevirir.
  ///
  /// Sunucu yarıçap süzgeci sunmuyor (`JobSearchCriteriaDto`'da mesafe alanı
  /// yok), yalnız kutu var. Kutu daireden büyük — köşelerde yarıçapın biraz
  /// dışına taşan ilanlar da dönüyor; süzgecin sayfalandıkça yanlışa düşmemesi
  /// bu küçük fazlalığa değiyor.
  JobSearchQuery withRadius({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) {
    final latitudeDelta = radiusKm / _kmPerLatitudeDegree;

    // Boylam dereceleri kutuplara doğru daralıyor; enlem kosinüsüyle
    // düzeltilmezse kuzeyde kutu gerçekte olduğundan dar kalır.
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

  /// Bir enlem derecesinin kabaca kaç kilometre olduğu.
  static const double _kmPerLatitudeDegree = 111.32;
}
