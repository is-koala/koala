import 'dart:math' as math;

import 'package:koala/employee/features/home/models/job.dart';

/// `GET /jobs` sıralama seçenekleri.
///
/// Sunucu sıralamayı **beyaz listeliyor**: listede olmayan bir alan boş sonuç
/// değil, `400` (`PAGE_SORT_FIELD_NOT_ALLOWED`) döndürüyor. Bu yüzden seçenekler
/// elle dize yazılarak değil, yalnızca buradan üretiliyor — enum'a girmeyen bir
/// alan uygulamadan hiç çıkamıyor.
enum JobSortOption {
  newest('createdAt', _descending, 'En yeni'),
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
}

/// `copyWith`'te "dokunma" ile "temizle"yi ayıran nöbetçi.
///
/// Süzgeç çipleri tek tek kaldırılabildiği için `copyWith(categoryId: null)`
/// çağrısının alanı **sıfırlaması** gerekiyor; sıradan bir `String?` parametrede
/// bu "verilmedi" ile aynı şeye denk düşerdi.
const Object _unset = Object();

/// Keşfet'in sunucuya gönderdiği arama ölçütleri.
///
/// Alanlar backend'deki `JobSearchCriteriaDto` ile **birebir**: uydurma alan
/// yok, sunucuda karşılığı olmayan bir süzgeç buraya girmiyor. Liste ve harita
/// sekmeleri aynı tipi kullanıyor; ayrı iki sorgu arayüzü olsaydı iki sekme
/// zamanla ayrışırdı.
///
/// Mesafe (yarıçap) sunucuda **yok**; en yakın karşılık sınırlayıcı kutu, bkz.
/// [withRadius].
class JobSearchQuery {
  const JobSearchQuery({
    this.query,
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
    this.minLatitude,
    this.maxLatitude,
    this.minLongitude,
    this.maxLongitude,
    this.sort = JobSortOption.newest,
  });

  /// Serbest metin araması: başlık, pozisyon, şirket ve konumda aranıyor.
  final String? query;

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

  /// Haritanın görünen alanı. Dördü birlikte anlamlı.
  final double? minLatitude;
  final double? maxLatitude;
  final double? minLongitude;
  final double? maxLongitude;

  final JobSortOption sort;

  /// Serbest metin araması var mı.
  bool get hasQuery => query != null && query!.trim().isNotEmpty;

  /// Metin araması ve sıralama **dışında** bir ölçüt seçili mi.
  ///
  /// Boş sonuç ekranı "hiç ilan yok" ile "bu süzgece uyan ilan yok"u ayırmak
  /// için buna bakıyor.
  bool get hasFilters =>
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
      hasBounds;

  /// Sınırlayıcı kutunun dördü de dolu mu.
  bool get hasBounds =>
      minLatitude != null ||
      maxLatitude != null ||
      minLongitude != null ||
      maxLongitude != null;

  /// Ne arama ne süzgeç var: kullanıcı Keşfet'i olduğu gibi görüyor.
  bool get isEmpty => !hasQuery && !hasFilters;

  /// `GET /jobs` sorgu parametreleri. Boş alanlar **konmuyor** — seçilmemiş bir
  /// süzgeç istekte görünmemeli.
  Map<String, dynamic> toQueryParameters() {
    return {
      'query': ?(hasQuery ? query!.trim() : null),
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
      'minLatitude': ?minLatitude,
      'maxLatitude': ?maxLatitude,
      'minLongitude': ?minLongitude,
      'maxLongitude': ?maxLongitude,
      'sort': ?(sort.isDefault ? null : sort.parameter),
    };
  }

  /// Alan güncelleyip yeni bir sorgu üretir.
  ///
  /// `null` geçmek alanı **temizler**; hiç geçmemek olduğu gibi bırakır — bkz.
  /// [_unset].
  JobSearchQuery copyWith({
    Object? query = _unset,
    Object? categoryId = _unset,
    Object? cityId = _unset,
    Object? districtId = _unset,
    Object? type = _unset,
    Object? salaryType = _unset,
    Object? employerType = _unset,
    Object? minSalary = _unset,
    Object? maxSalary = _unset,
    Object? insuranceRequired = _unset,
    Object? experienceRequired = _unset,
    Object? minLatitude = _unset,
    Object? maxLatitude = _unset,
    Object? minLongitude = _unset,
    Object? maxLongitude = _unset,
    JobSortOption? sort,
  }) {
    return JobSearchQuery(
      query: _pick(query, this.query),
      categoryId: _pick(categoryId, this.categoryId),
      cityId: _pick(cityId, this.cityId),
      districtId: _pick(districtId, this.districtId),
      type: _pick(type, this.type),
      salaryType: _pick(salaryType, this.salaryType),
      employerType: _pick(employerType, this.employerType),
      minSalary: _pick(minSalary, this.minSalary),
      maxSalary: _pick(maxSalary, this.maxSalary),
      insuranceRequired: _pick(insuranceRequired, this.insuranceRequired),
      experienceRequired: _pick(experienceRequired, this.experienceRequired),
      minLatitude: _pick(minLatitude, this.minLatitude),
      maxLatitude: _pick(maxLatitude, this.maxLatitude),
      minLongitude: _pick(minLongitude, this.minLongitude),
      maxLongitude: _pick(maxLongitude, this.maxLongitude),
      sort: sort ?? this.sort,
    );
  }

  /// Sınırlayıcı kutuyu temizler; kutu dört alan olduğu için tek tek
  /// `copyWith(minLatitude: null, ...)` yazmak çağrı yerlerini kirletiyordu.
  JobSearchQuery withoutBounds() {
    return copyWith(
      minLatitude: null,
      maxLatitude: null,
      minLongitude: null,
      maxLongitude: null,
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
      minLatitude: latitude - latitudeDelta,
      maxLatitude: latitude + latitudeDelta,
      minLongitude: longitude - longitudeDelta,
      maxLongitude: longitude + longitudeDelta,
    );
  }

  /// Bir enlem derecesinin kabaca kaç kilometre olduğu.
  static const double _kmPerLatitudeDegree = 111.32;

  /// Nöbetçi parametreler `Object?` olduğu için derleyici tip uyuşmazlığını
  /// yakalayamıyor: `copyWith(minSalary: 100)` sorunsuz derleniyor ama `int`
  /// bir `double?` alana atanamadığı için çalışma anında patlıyordu. Sayısal
  /// alanlarda dönüştürme burada yapılıyor.
  static T? _pick<T>(Object? candidate, T? current) {
    if (identical(candidate, _unset)) return current;
    if (candidate is int && <double?>[] is List<T?>) {
      return candidate.toDouble() as T?;
    }
    return candidate as T?;
  }
}
