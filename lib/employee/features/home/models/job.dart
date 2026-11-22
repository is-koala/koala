import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';

/// İş kategorisi; kaynak `GET /reference/job-categories`. İkon, renk ve pin
/// [code] üzerinden ([JobCategoryStyle]).
class JobCategory {
  const JobCategory({
    required this.id,
    required this.name,
    required this.code,
    this.requiresInsurance = false,
  });

  /// Süzgeçler (`categoryId`) bununla gönderiliyor.
  final String id;

  final String name;

  /// Addan türetilen sabit anahtar (`FOTOGRAFCILIK`); ad değişse de kod kalır.
  final String code;

  final bool requiresInsurance;

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
  /// geliyor.
  @override
  bool operator ==(Object other) => other is JobCategory && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Kategorinin görseli; tanınmayan kod marka yeşili ve genel ikonla çizilir.
extension JobCategoryStyle on JobCategory {
  AppIconData get icon {
    switch (code) {
      case JobCategoryCodes.photography:
        return AppIcons.camera;
      case JobCategoryCodes.waiter:
        return AppIcons.foodTray;
      case JobCategoryCodes.petCare:
        return AppIcons.pet;
      case JobCategoryCodes.design:
        return AppIcons.paintbrush;
      case JobCategoryCodes.barista:
        return AppIcons.coffee;
      default:
        return AppIcons.briefcase;
    }
  }

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
}

/// Çizim varlığı olan kodlar; backend `job_categories.code` ile aynı olmalı.
/// Uyuşmazsa hata yok, sessizce varsayılana düşer: değiştirirken seed
/// changeset'iyle karşılaştır.
class JobCategoryCodes {
  const JobCategoryCodes._();

  static const String photography = 'PHOTOGRAPHY';
  static const String waiter = 'WAITER';
  static const String petCare = 'PET_CARE';
  static const String design = 'DESIGN';
  static const String barista = 'BARISTA';
}

/// Testlerin örnek kategorileri; **gerçek kayıt değil** (`seed-` önekli).
/// `lib/` altında okuyan yok, öyle kalmalı.
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

  static const List<JobCategory> all = [
    photography,
    waiter,
    petCare,
    design,
    barista,
  ];
}

/// Sunucuda `ONE_TIME` / `RECURRING`; eşleşme [code] ile.
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

/// İlan durumu; atama yaşam döngüsü [MyJobStatus] / `AssignmentStatus`.
enum JobStatus {
  open('OPEN', 'Açık'),
  closed('CLOSED', 'Kapalı'),
  cancelled('CANCELLED', 'İptal edildi');

  const JobStatus(this.code, this.displayName);

  final String code;
  final String displayName;

  /// Keşfette yalnız bunlar.
  bool get isOpen => this == JobStatus.open;

  static JobStatus fromCode(Object? value) {
    return JobStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => JobStatus.closed,
    );
  }
}

/// Konumun kesinliği. Tanınmayan ya da eksik değer **yaklaşık**'a düşer:
/// bilinmeyeni kesin saymak yuvarlanmış koordinatı iş adresi gibi çizer
/// (ADR-0003).
enum AddressPrecision {
  approximate('APPROXIMATE'),
  exact('EXACT');

  const AddressPrecision(this.code);

  final String code;

  /// "Bu konum yaklaşık mı?" sorusunun **tek** yeri. `!= exact` bilerek: yeni
  /// bir kesinlik eklenirse `== approximate` onu sessizce kesin sayardı.
  bool get isApproximate => this != AddressPrecision.exact;

  static AddressPrecision fromCode(Object? value) {
    return AddressPrecision.values.firstWhere(
      (precision) => precision.code == value,
      orElse: () => AddressPrecision.approximate,
    );
  }
}

/// İlanın liste/harita görünümü (`JobSummaryDto`). Açıklama, görevler ve tam
/// adres [JobDetail]'de.
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
    this.companyId,
    this.companyLogoUrl,
    this.coverImageUrl,
    this.applicationCount = 0,
    this.headcount,
    this.hiredCount = 0,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.addressPrecision = AddressPrecision.approximate,
    this.hasShuttle = false,
  });

  final String id;
  final String title;
  final JobCategory category;
  final JobType type;
  final JobEmployerType employerType;
  final SalaryType salaryType;

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

  /// Bireysel ilanda `null`.
  final String? company;

  /// Bireysel ilanda `null`; şirket detayı bu kimliği ister.
  final String? companyId;

  /// Eski sunucuda ve bireysel ilanda `null`.
  final String? companyLogoUrl;

  /// Kart için galeri kapağı; tam galeri ayrı uçtan.
  final String? coverImageUrl;

  /// Yanıtlanmışlar dâhil; yalnız işverenin listesi kullanıyor.
  final int applicationCount;

  final int? headcount;

  final int hiredCount;

  /// Opsiyonel; koordinatsız ilan haritada gösterilemez ([hasLocation]).
  final double? latitude;
  final double? longitude;

  /// Yalnız istekte `lat`/`lng` varken dolar; istemci yeniden hesaplamaz.
  /// `null` satırı gizler.
  final double? distanceKm;

  /// Koordinatın kesinliği. Koordinat **her zaman** var, yetkisizde
  /// yuvarlanıyor; bayrağı okumamak yuvarlanmış noktayı kesin adres gibi çizer
  /// (#93).
  final AddressPrecision addressPrecision;

  /// Eski sunucuda `false`.
  final bool hasShuttle;

  bool get hasLocation => latitude != null && longitude != null;

  /// Yaklaşık koordinatın gerçek noktaya en büyük uzaklığı. Sunucu iki ondalığa
  /// yuvarlıyor (±0.005°); köşegen alındığı için daire gerçek konumu
  /// **kapsıyor**. İstemci yuvarlaması değil, sunucunun belirsizliğinin çizimi.
  /// Kesin konumda **sıfır**.
  double get approximateRadiusInMeters {
    if (!addressPrecision.isApproximate) return 0;

    const latitudeError = _roundingHalfStep * _metersPerLatitudeDegree;
    final longitudeError = latitudeError * cos((latitude ?? 0) * pi / 180);
    return sqrt(
      latitudeError * latitudeError + longitudeError * longitudeError,
    );
  }

  /// Uzaklık metni. Yaklaşık konum ±557 m taşıdığı için "2,3 km" yanlış
  /// çözünürlük iddia eder (#93): tam kilometreye yuvarlanır ve `~` eklenir;
  /// hata payından küçükse sayı yazılmaz.
  String distanceLabel(double kilometersAway) {
    if (!addressPrecision.isApproximate) {
      return '${kilometersAway.toStringAsFixed(1)} km';
    }

    final rounded = kilometersAway.round();
    return rounded < 1 ? "1 km'den yakın" : '~$rounded km';
  }

  /// Ham koordinat metni; yaklaşıkta iki ondalık, kesinde dört. Daha fazla hane
  /// olmayan bir kesinlik uydururdu.
  String get coordinateLabel {
    final fractionDigits = addressPrecision.isApproximate
        ? _approximateFractionDigits
        : _exactFractionDigits;

    return '${latitude!.toStringAsFixed(fractionDigits)}, '
        '${longitude!.toStringAsFixed(fractionDigits)}';
  }

  static const int _approximateFractionDigits = 2;

  static const int _exactFractionDigits = 4;

  static const double _roundingHalfStep = 0.005;

  static const double _metersPerLatitudeDegree = 111320;

  /// Pozisyon → sektör → kategori adı.
  String get subtitle {
    if (position != null && position!.isNotEmpty) return position!;
    if (sector != null && sector!.isNotEmpty) return sector!;
    return category.displayName;
  }

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
      companyId: json['companyId'] as String?,
      companyLogoUrl: json['companyLogoUrl'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      applicationCount: (json['applicationCount'] as num?)?.toInt() ?? 0,
      headcount: (json['headcount'] as num?)?.toInt(),
      hiredCount: (json['hiredCount'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      addressPrecision: AddressPrecision.fromCode(json['addressPrecision']),
      hasShuttle: json['hasShuttle'] as bool? ?? false,
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
      'companyId': companyId,
      'companyLogoUrl': companyLogoUrl,
      'coverImageUrl': coverImageUrl,
      'applicationCount': applicationCount,
      'headcount': headcount,
      'hiredCount': hiredCount,
      'latitude': latitude,
      'longitude': longitude,
      'distanceKm': distanceKm,
      'addressPrecision': addressPrecision.code,
      'hasShuttle': hasShuttle,
    };
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
