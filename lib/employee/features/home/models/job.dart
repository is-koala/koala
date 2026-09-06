import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';

/// Bir iş kategorisi.
///
/// Kaynağı `GET /reference/job-categories`; uygulama artık sabit bir liste
/// tutmuyor, backend hangi kategorileri döndürüyorsa onlar geçerli. İkon, renk
/// ve harita pini [code] üzerinden eşleşiyor — bkz. [JobCategoryStyle].
class JobCategory {
  const JobCategory({
    required this.id,
    required this.name,
    required this.code,
    this.requiresInsurance = false,
  });

  /// Backend'deki UUID. Filtreler (`categoryId`) bununla gönderiliyor.
  final String id;

  /// Görünen Türkçe ad: `Fotoğrafçılık`.
  final String name;

  /// Ada göre türetilen sabit anahtar: `FOTOGRAFCILIK`. Görsel eşleşme buna
  /// bakıyor, çünkü ad değişse bile kod sabit kalıyor.
  final String code;

  /// Bu kategorideki işler sigorta zorunlu mu.
  final bool requiresInsurance;

  /// Arayüzde gösterilen ad. [name] ile aynı; çağrı yerleri okunur kalsın diye.
  String get displayName => name;

  factory JobCategory.fromJson(Map<String, dynamic> json) {
    return JobCategory(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      requiresInsurance: json['requiresInsurance'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'requiresInsurance': requiresInsurance,
    };
  }

  /// Eşitlik [code] üzerinden: aynı kategori farklı isteklerden farklı nesne
  /// olarak geliyor, filtre karşılaştırması yine de tutmalı.
  @override
  bool operator ==(Object other) => other is JobCategory && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Kategorinin görsel karşılığı.
///
/// Uygulama beş kategori için çizim varlığı taşıyor. Backend bunların dışında
/// bir kategori döndürebildiği için her eşleşmenin bir yedeği var: tanınmayan
/// kod marka yeşiliyle ve genel bir ikonla çiziliyor, ekran boş kalmıyor.
extension JobCategoryStyle on JobCategory {
  /// Kategorinin ikonu.
  AppIconData get icon {
    switch (code) {
      case JobCategoryCodes.photography:
        return AppIcons.camera;
      case JobCategoryCodes.waiter:
        return AppIcons.restaurant;
      case JobCategoryCodes.petCare:
        return AppIcons.penTool;
      case JobCategoryCodes.design:
        return AppIcons.paint;
      case JobCategoryCodes.barista:
        return AppIcons.coffee;
      default:
        return AppIcons.work;
    }
  }

  /// Kategorinin rengi.
  Color get color {
    switch (code) {
      case JobCategoryCodes.photography:
        return AppColors.categoryPhotography;
      case JobCategoryCodes.waiter:
        return AppColors.categoryWaiter;
      case JobCategoryCodes.petCare:
        return AppColors.categoryPetCare;
      case JobCategoryCodes.design:
        return AppColors.categoryDesign;
      case JobCategoryCodes.barista:
        return AppColors.categoryBarista;
      default:
        return AppColors.primaryColor;
    }
  }

  /// Haritadaki pinin SVG yolu.
  ///
  /// TODO(tasarım): Tanınmayan kategori için nötr bir pin görseli yok; şimdilik
  /// garson pini marka yeşiline boyanarak kullanılıyor (`JobMarkerGenerator`
  /// SVG'deki rengi değiştiriyor). `assets/map_pins/default.svg` eklenmeli.
  String get pinAsset {
    switch (code) {
      case JobCategoryCodes.photography:
        return 'assets/map_pins/photography.svg';
      case JobCategoryCodes.petCare:
        return 'assets/map_pins/pet_care.svg';
      case JobCategoryCodes.design:
        return 'assets/map_pins/design.svg';
      case JobCategoryCodes.barista:
        return 'assets/map_pins/barista.svg';
      case JobCategoryCodes.waiter:
      default:
        return 'assets/map_pins/waiter.svg';
    }
  }
}

/// Uygulamanın çizim varlığı taşıdığı kategori kodları.
///
/// Değerler backend'deki `job_categories.code` ile birebir aynı olmalı; ikon,
/// renk ve pin eşleşmesi buna bakıyor. Uyuşmazsa hata alınmıyor — kategori
/// sessizce varsayılan görünüme düşüyor, o yüzden değiştirirken seed
/// changeset'iyle karşılaştır (`27-10-job-category-seed.xml`).
class JobCategoryCodes {
  const JobCategoryCodes._();

  static const String photography = 'PHOTOGRAPHY';
  static const String waiter = 'WAITER';
  static const String petCare = 'PET_CARE';
  static const String design = 'DESIGN';
  static const String barista = 'BARISTA';
}

/// Testlerin kullandığı örnek kategoriler.
///
/// **Gerçek kayıt değil.** Backend `GET /reference/job-categories`'ten gelen
/// kategorilerin `id`'si UUID; buradakiler bilerek `seed-` önekli, ki bir
/// filtre yanlışlıkla gerçek bir kayda eşleşmesin. `lib/` altında okuyan
/// kalmadı — yalnızca `test/support/fixtures.dart` ve kategori testleri
/// kullanıyor, öyle kalmalı.
class JobCategorySeeds {
  const JobCategorySeeds._();

  static const JobCategory photography = JobCategory(
    id: 'seed-fotografcilik',
    name: 'Fotoğrafçılık',
    code: JobCategoryCodes.photography,
  );

  static const JobCategory waiter = JobCategory(
    id: 'seed-garsonluk',
    name: 'Garsonluk',
    code: JobCategoryCodes.waiter,
  );

  static const JobCategory petCare = JobCategory(
    id: 'seed-hayvan-bakimi',
    name: 'Hayvan Bakımı',
    code: JobCategoryCodes.petCare,
  );

  static const JobCategory design = JobCategory(
    id: 'seed-tasarim',
    name: 'Tasarım',
    code: JobCategoryCodes.design,
  );

  static const JobCategory barista = JobCategory(
    id: 'seed-barista',
    name: 'Barista',
    code: JobCategoryCodes.barista,
  );

  /// Sahte veri üretenlerin döndüğü liste.
  static const List<JobCategory> all = [
    photography,
    waiter,
    petCare,
    design,
    barista,
  ];
}

/// İş tipi. Backend `JobType` karşılığı.
///
/// Sunucudaki değerler `ONE_TIME` / `RECURRING`; Dart tarafındaki adlarla
/// aynı olmadığı için eşleşme [code] üzerinden yapılıyor.
enum JobType {
  oneTime('ONE_TIME', 'Günlük'),
  recurring('RECURRING', 'Tekrarlı');

  const JobType(this.code, this.displayName);

  final String code;
  final String displayName;

  static JobType fromCode(Object? value) {
    return JobType.values.firstWhere(
      (type) => type.code == value,
      orElse: () => JobType.oneTime,
    );
  }
}

/// Ücretin hangi birim üzerinden verildiği. Backend `SalaryType` karşılığı.
enum SalaryType {
  hourly('HOURLY', 'Saatlik'),
  daily('DAILY', 'Günlük');

  const SalaryType(this.code, this.displayName);

  final String code;
  final String displayName;

  static SalaryType fromCode(Object? value) {
    return SalaryType.values.firstWhere(
      (type) => type.code == value,
      orElse: () => SalaryType.daily,
    );
  }
}

/// İlanı kimin açtığı. Backend `JobEmployerType` karşılığı.
enum JobEmployerType {
  company('COMPANY', 'Kurumsal'),
  individual('INDIVIDUAL', 'Bireysel');

  const JobEmployerType(this.code, this.displayName);

  final String code;
  final String displayName;

  static JobEmployerType fromCode(Object? value) {
    return JobEmployerType.values.firstWhere(
      (type) => type.code == value,
      orElse: () => JobEmployerType.company,
    );
  }
}

/// İlanın durumu. Backend `JobStatus` karşılığı.
enum JobStatus {
  open('OPEN', 'Açık'),
  inProgress('IN_PROGRESS', 'Devam ediyor'),
  closed('CLOSED', 'Kapalı'),
  cancelled('CANCELLED', 'İptal edildi'),
  completed('COMPLETED', 'Tamamlandı');

  const JobStatus(this.code, this.displayName);

  final String code;
  final String displayName;

  /// Başvuruya açık mı. Keşfette yalnızca bunlar gösteriliyor.
  bool get isOpen => this == JobStatus.open;

  static JobStatus fromCode(Object? value) {
    return JobStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => JobStatus.open,
    );
  }
}

/// Bir iş ilanının liste/harita görünümü.
///
/// `GET /jobs` yanıtındaki `JobSummaryDto`'nun karşılığı. Açıklama, görevler,
/// yaş aralığı ve tam adres burada **yok** — onlar `GET /jobs/{id}` ile gelen
/// [JobDetail]'de. Kart ya da pin çizmek için gereken her şey burada.
class Job {
  const Job({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    required this.employerType,
    required this.salaryType,
    required this.price,
    required this.status,
    this.position,
    this.sector,
    this.insuranceRequired = false,
    this.experienceRequired = false,
    this.startDateTime,
    this.endDateTime,
    this.cityName,
    this.districtName,
    this.company,
    this.coverImageUrl,
    this.applicationCount = 0,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String title;
  final JobCategory category;
  final JobType type;
  final JobEmployerType employerType;
  final SalaryType salaryType;

  /// Ücret. Backend'de `salary`.
  final double price;

  final JobStatus status;

  final String? position;
  final String? sector;
  final bool insuranceRequired;
  final bool experienceRequired;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final String? cityName;
  final String? districtName;

  /// İlanı açan şirketin adı. Bireysel ilanlarda `null`.
  final String? company;

  /// Arama/listeme kartında gösterilen ilan galerisi kapağı.
  ///
  /// Tam galeri ayrı uçtan yüklenir; özet yanıtı kart için yalnızca bu
  /// URL'yi taşır.
  final String? coverImageUrl;

  /// İlana gelen toplam başvuru sayısı — yanıtlanmışlar dâhil.
  ///
  /// Yalnızca işverenin listesi kullanıyor; keşfette anlamı yok. Sunucu bu
  /// sayıyı ilan listesiyle aynı geçişte doldurduğu için başvuru sayısını
  /// göstermek ayrı bir istek gerektirmiyor.
  final int applicationCount;

  /// Konum. Backend bu iki alanı **opsiyonel** döndürüyor; adresi
  /// koordinata çevrilmemiş ilanlar haritada gösterilemiyor — bkz. [hasLocation].
  final double? latitude;
  final double? longitude;

  /// Haritada pin çizilebilir mi.
  bool get hasLocation => latitude != null && longitude != null;

  /// Kartın ikinci satırı.
  ///
  /// Backend'de bunun doğrudan karşılığı yok; en açıklayıcıdan en genele
  /// doğru düşülüyor: pozisyon → sektör → kategori adı.
  String get subtitle {
    if (position != null && position!.isNotEmpty) return position!;
    if (sector != null && sector!.isNotEmpty) return sector!;
    return category.displayName;
  }

  /// `Küçükçekmece/İstanbul`. İkisi de boşsa `null`.
  String? get locationLabel {
    final parts = [
      if (districtName != null && districtName!.isNotEmpty) districtName!,
      if (cityName != null && cityName!.isNotEmpty) cityName!,
    ];
    return parts.isEmpty ? null : parts.join('/');
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: '${json['id']}',
      title: json['title'] as String? ?? '',
      category: JobCategory.fromJson(
        (json['category'] as Map<String, dynamic>?) ?? const {},
      ),
      type: JobType.fromCode(json['type']),
      employerType: JobEmployerType.fromCode(json['employerType']),
      salaryType: SalaryType.fromCode(json['salaryType']),
      price: (json['salary'] as num?)?.toDouble() ?? 0,
      status: JobStatus.fromCode(json['status']),
      position: json['position'] as String?,
      sector: json['sector'] as String?,
      insuranceRequired: json['insuranceRequired'] as bool? ?? false,
      experienceRequired: json['experienceRequired'] as bool? ?? false,
      startDateTime: _parseDate(json['startDateTime']),
      endDateTime: _parseDate(json['endDateTime']),
      cityName: json['cityName'] as String?,
      districtName: json['districtName'] as String?,
      company: json['companyName'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      applicationCount: (json['applicationCount'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category.toJson(),
      'type': type.code,
      'employerType': employerType.code,
      'salaryType': salaryType.code,
      'salary': price,
      'status': status.code,
      'position': position,
      'sector': sector,
      'insuranceRequired': insuranceRequired,
      'experienceRequired': experienceRequired,
      'startDateTime': startDateTime?.toIso8601String(),
      'endDateTime': endDateTime?.toIso8601String(),
      'cityName': cityName,
      'districtName': districtName,
      'companyName': company,
      'coverImageUrl': coverImageUrl,
      'applicationCount': applicationCount,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
