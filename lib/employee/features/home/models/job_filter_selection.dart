import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/employee/features/home/models/job_start_on.dart';
import 'package:koala/product/extensions/num_extensions.dart';
import 'package:koala/product/models/copy_with.dart';
import 'package:koala/product/models/reference_location.dart';

/// Süzgeç çubuğunda tek tek kaldırılabilen alanlar.
enum JobFilterField {
  category,
  type,
  city,
  district,
  salaryType,
  employerType,

  /// Alt ve üst sınır **tek** çip: kullanıcı bir aralık seçiyor, iki sayı
  /// değil.
  salary,
  insurance,
  experience,
  distance,
  startOn,
}

/// Çubukta özetlenen etkin bir süzgeç.
class ActiveJobFilter {
  const ActiveJobFilter(this.field, this.label);

  final JobFilterField field;

  /// Çipin üzerinde yazan ad.
  final String label;
}

/// Süzgeç sheet'inin durumu — [JobSearchQuery]'nin arayüz tarafındaki eşi.
///
/// Neden ayrı bir tip: sorgu sunucunun dili, bu ise kullanıcının. Sorgu
/// `categoryId` taşıyor ama çipte kategorinin **adı** yazıyor; sorgu
/// sınırlayıcı kutu taşıyor ama kullanıcı "10 km içinde" seçiyor. Kutudan
/// kilometreye geri dönülemediği için seçim burada tutuluyor ve
/// [toQuery] tek yönde çeviriyor.
///
/// Sıralama süzgeç sayılmıyor: her zaman bir değeri var, "kaç süzgeç açık"
/// sayısına ve "temizle"ye girmiyor.
class JobFilterSelection {
  const JobFilterSelection({
    this.category,
    this.type,
    this.city,
    this.district,
    this.salaryType,
    this.employerType,
    this.minSalary,
    this.maxSalary,
    this.insuranceRequired,
    this.experienceRequired,
    this.radiusKm,
    this.startOn,
    this.sort = JobSortOption.newest,
  });

  final JobCategory? category;
  final JobType? type;
  final ReferenceLocation? city;
  final ReferenceLocation? district;
  final SalaryType? salaryType;
  final JobEmployerType? employerType;
  final double? minSalary;
  final double? maxSalary;
  final bool? insuranceRequired;
  final bool? experienceRequired;

  /// Kullanıcının seçtiği mesafe kovası. Sunucuda yarıçap süzgeci yok; bu
  /// değer [toQuery]'de sınırlayıcı kutuya çevriliyor ve yalnız konum
  /// biliniyorsa uygulanıyor.
  final double? radiusKm;

  /// Başlangıç günü çipi. [toQuery] bunu `startFrom`/`startTo` Instant
  /// penceresine çevirir.
  final JobStartOn? startOn;

  final JobSortOption sort;

  /// Etkin süzgeçler, çubukta çizilecek sırayla.
  List<ActiveJobFilter> get activeFilters => [
    if (category != null)
      ActiveJobFilter(JobFilterField.category, category!.displayName),
    if (type != null) ActiveJobFilter(JobFilterField.type, type!.displayName),
    if (city != null) ActiveJobFilter(JobFilterField.city, city!.name),
    if (district != null)
      ActiveJobFilter(JobFilterField.district, district!.name),
    if (salaryType != null)
      ActiveJobFilter(JobFilterField.salaryType, salaryType!.displayName),
    if (employerType != null)
      ActiveJobFilter(JobFilterField.employerType, employerType!.displayName),
    if (minSalary != null || maxSalary != null)
      ActiveJobFilter(JobFilterField.salary, _salaryLabel),
    if (insuranceRequired != null)
      ActiveJobFilter(
        JobFilterField.insurance,
        insuranceRequired! ? 'Sigortalı' : 'Sigortasız',
      ),
    if (experienceRequired != null)
      ActiveJobFilter(
        JobFilterField.experience,
        experienceRequired! ? 'Deneyim şartlı' : 'Deneyim şartsız',
      ),
    if (radiusKm != null)
      ActiveJobFilter(
        JobFilterField.distance,
        '${radiusKm!.toStringAsFixed(0)} km içinde',
      ),
    if (startOn != null)
      ActiveJobFilter(JobFilterField.startOn, startOn!.label),
  ];

  int get activeCount => activeFilters.length;

  bool get isEmpty => activeFilters.isEmpty;

  String get _salaryLabel {
    final min = minSalary;
    final max = maxSalary;
    if (min != null && max != null) return '${min.asPrice}₺ - ${max.asPrice}₺';
    if (min != null) return '${min.asPrice}₺ ve üzeri';
    return 'en çok ${max!.asPrice}₺';
  }

  /// Sunucu sorgusuna çevirir.
  ///
  /// [latitude]/[longitude] verilmezse [radiusKm] **uygulanmıyor**: konum
  /// bilinmeden kutu hesaplanamaz. Arayüz bu durumda süzgeci sessizce
  /// düşürmüyor, seçeneği hiç açmıyor.
  JobSearchQuery toQuery({
    String? searchText,
    double? latitude,
    double? longitude,
    DateTime? now,
  }) {
    final window = startOn?.toWindow(now: now);
    final query = JobSearchQuery(
      query: searchText,
      categoryId: category?.id,
      cityId: city?.id,
      districtId: district?.id,
      type: type,
      salaryType: salaryType,
      employerType: employerType,
      minSalary: minSalary,
      maxSalary: maxSalary,
      insuranceRequired: insuranceRequired,
      experienceRequired: experienceRequired,
      latitude: latitude,
      longitude: longitude,
      startFrom: window?.startFrom,
      startTo: window?.startTo,
      sort: sort,
    );

    if (radiusKm == null || latitude == null || longitude == null) return query;

    return query.withRadius(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm!,
    );
  }

  /// Tek bir süzgeci kaldırır — çubuktaki çipin çarpısı buna bağlı.
  JobFilterSelection without(JobFilterField field) {
    return switch (field) {
      JobFilterField.category => copyWith(category: null),
      JobFilterField.type => copyWith(type: null),
      // İl düşünce ilçe de düşüyor: başka bir ilin ilçesi sorguda kalırsa
      // sonuç boş döner ve sebebi ekranda görünmez.
      JobFilterField.city => copyWith(city: null, district: null),
      JobFilterField.district => copyWith(district: null),
      JobFilterField.salaryType => copyWith(salaryType: null),
      JobFilterField.employerType => copyWith(employerType: null),
      JobFilterField.salary => copyWith(minSalary: null, maxSalary: null),
      JobFilterField.insurance => copyWith(insuranceRequired: null),
      JobFilterField.experience => copyWith(experienceRequired: null),
      JobFilterField.distance => copyWith(radiusKm: null),
      JobFilterField.startOn => copyWith(startOn: null),
    };
  }

  /// Bütün süzgeçleri sıfırlar. Sıralama korunuyor — o bir süzgeç değil,
  /// listenin okunma biçimi.
  JobFilterSelection cleared() => JobFilterSelection(sort: sort);

  /// Alan güncelleyip yeni bir seçim üretir; `null` geçmek alanı **temizler**,
  /// hiç geçmemek olduğu gibi bırakır — bkz. [CopyWith].
  JobFilterSelection copyWith({
    Object? category = CopyWith.unset,
    Object? type = CopyWith.unset,
    Object? city = CopyWith.unset,
    Object? district = CopyWith.unset,
    Object? salaryType = CopyWith.unset,
    Object? employerType = CopyWith.unset,
    Object? minSalary = CopyWith.unset,
    Object? maxSalary = CopyWith.unset,
    Object? insuranceRequired = CopyWith.unset,
    Object? experienceRequired = CopyWith.unset,
    Object? radiusKm = CopyWith.unset,
    Object? startOn = CopyWith.unset,
    JobSortOption? sort,
  }) {
    return JobFilterSelection(
      category: CopyWith.pick(category, this.category),
      type: CopyWith.pick(type, this.type),
      city: CopyWith.pick(city, this.city),
      district: CopyWith.pick(district, this.district),
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
      radiusKm: CopyWith.pick(radiusKm, this.radiusKm),
      startOn: CopyWith.pick(startOn, this.startOn),
      sort: sort ?? this.sort,
    );
  }
}
