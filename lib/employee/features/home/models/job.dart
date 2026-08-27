import 'package:flutter/material.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
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

/// Sahte servislerin ve testlerin kullandığı örnek kategoriler.
///
/// **Gerçek kayıt değil.** Backend `GET /reference/job-categories`'ten gelen
/// kategorilerin `id`'si UUID; buradakiler bilerek `seed-` önekli, ki bir
/// filtre yanlışlıkla gerçek bir kayda eşleşmesin. `JobService` gerçek uca
/// bağlandığında bu sınıf da sahte verilerle birlikte silinecek.
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

/// İş tipini temsil eden enum (Günlük veya Tekrarlı)
enum JobType { oneTime, recurring }

/// JobType için extension - Türkçe isimler
extension JobTypeExtension on JobType {
  String get displayName {
    switch (this) {
      case JobType.oneTime:
        return 'Günlük';
      case JobType.recurring:
        return 'Tekrarlı';
    }
  }
}

class Job {
  final String id;
  final double latitude;
  final double longitude;
  final JobType type;
  final JobCategory category;
  final String title;
  final String subtitle;
  final double price;
  final String? imageUrl;
  final String? company;
  final Company? companyDetails;
  final String? description;
  final String? sector;
  final String? position;
  final String? duties;
  final bool? insuranceRequired;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final String? salaryType;
  final int? minAge;
  final int? maxAge;
  final bool? experienceRequired;
  final String? dressCode;
  final String? employerType;
  final String? address;

  const Job({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.price,
    this.imageUrl,
    this.company,
    this.companyDetails,
    this.description,
    this.sector,
    this.position,
    this.duties,
    this.insuranceRequired,
    this.startDateTime,
    this.endDateTime,
    this.salaryType,
    this.minAge,
    this.maxAge,
    this.experienceRequired,
    this.dressCode,
    this.employerType,
    this.address,
  });

  /// JSON'dan model oluşturma
  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      type: JobType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => JobType.oneTime,
      ),
      category: JobCategory.fromJson(json['category']! as Map<String, dynamic>),
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String?,
      company: json['company'] as String?,
      companyDetails: json['companyDetails'] != null
          ? Company.fromJson(json['companyDetails'] as Map<String, dynamic>)
          : null,
      description: json['description'] as String?,
      sector: json['sector'] as String?,
      position: json['position'] as String?,
      duties: json['duties'] as String?,
      insuranceRequired: json['insuranceRequired'] as bool?,
      startDateTime: json['startDateTime'] != null
          ? DateTime.parse(json['startDateTime'] as String)
          : null,
      endDateTime: json['endDateTime'] != null
          ? DateTime.parse(json['endDateTime'] as String)
          : null,
      salaryType: json['salaryType'] as String?,
      minAge: json['minAge'] as int?,
      maxAge: json['maxAge'] as int?,
      experienceRequired: json['experienceRequired'] as bool?,
      dressCode: json['dressCode'] as String?,
      employerType: json['employerType'] as String?,
      address: json['address'] as String?,
    );
  }

  /// Model'den JSON oluşturma
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'type': type.name,
      'category': category.toJson(),
      'title': title,
      'subtitle': subtitle,
      'price': price,
      'imageUrl': imageUrl,
      'company': company,
      'companyDetails': companyDetails?.toJson(),
      'description': description,
      'sector': sector,
      'position': position,
      'duties': duties,
      'insuranceRequired': insuranceRequired,
      'startDateTime': startDateTime?.toIso8601String(),
      'endDateTime': endDateTime?.toIso8601String(),
      'salaryType': salaryType,
      'minAge': minAge,
      'maxAge': maxAge,
      'experienceRequired': experienceRequired,
      'dressCode': dressCode,
      'employerType': employerType,
      'address': address,
    };
  }
}
