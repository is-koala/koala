import 'dart:math' as math;

import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';
import 'package:koala/product/models/copy_with.dart';

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
    this.bounds,
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

  /// Haritanın görünen alanı.
  ///
  /// Dördü birlikte anlamlı olduğu için tek tip: dört ayrı `double?` "üçü dolu,
  /// biri boş" gibi sunucuya gönderilemeyecek bir durumu temsil edilebilir
  /// kılıyordu ve [JobMapBounds] zaten vardı.
  final JobMapBounds? bounds;

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

  /// Sınırlayıcı kutu seçili mi.
  ///
  /// Eskiden dört alanın **herhangi biri** doluysa `true` veriyordu ama doc'u
  /// "dördü de dolu mu" diyordu; tek alanla `true` dönen bir "dördü de" ifadesi
  /// okuyanı yanıltıyordu. Kutu tek bir alan olunca soru da tekilleşti.
  bool get hasBounds => bounds != null;

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
      'minLatitude': ?bounds?.minLatitude,
      'maxLatitude': ?bounds?.maxLatitude,
      'minLongitude': ?bounds?.minLongitude,
      'maxLongitude': ?bounds?.maxLongitude,
      'sort': ?(sort.isDefault ? null : sort.parameter),
    };
  }

  /// Alan güncelleyip yeni bir sorgu üretir.
  ///
  /// `null` geçmek alanı **temizler**; hiç geçmemek olduğu gibi bırakır — bkz.
  /// [CopyWith].
  JobSearchQuery copyWith({
    Object? query = CopyWith.unset,
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
    JobSortOption? sort,
  }) {
    return JobSearchQuery(
      query: CopyWith.pick(query, this.query),
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
