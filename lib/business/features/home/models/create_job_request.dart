import 'package:koala/employee/features/home/models/job.dart';

/// İlan açarken gönderilen adres.
///
/// Backend `CreateAddressRequestDto`'nun **beş** alanını zorunlu tutuyor:
/// `countryCode`, `cityName`, `addressLine`, `latitude`, `longitude`. Yani
/// koordinatsız ilan açılamıyor — ilçe ve posta kodu isteğe bağlı.
class CreateJobAddress {
  const CreateJobAddress({
    required this.countryCode,
    required this.cityName,
    required this.addressLine,
    required this.latitude,
    required this.longitude,
    this.districtName,
    this.postalCode,
  });

  final String countryCode;
  final String cityName;
  final String addressLine;
  final double latitude;
  final double longitude;
  final String? districtName;
  final String? postalCode;

  Map<String, dynamic> toJson() => {
    'countryCode': countryCode,
    'cityName': cityName,
    'districtName': ?districtName,
    'addressLine': addressLine,
    'postalCode': ?postalCode,
    'latitude': latitude,
    'longitude': longitude,
  };
}

/// Yeni ilan isteğinin gövdesi.
///
/// İki uca da aynı model gidiyor: `POST /users/me/jobs` (bireysel) ve
/// `POST /companies/{id}/jobs` (kurumsal). Tek fark [insuranceRequired] —
/// `CreateIndividualJobDto` o alanı hiç taşımıyor, o yüzden bireysel istekte
/// gönderilmiyor (bkz. [toJson]).
class CreateJobRequest {
  const CreateJobRequest({
    required this.categoryId,
    required this.title,
    required this.description,
    required this.position,
    required this.address,
    required this.type,
    required this.salaryType,
    required this.salary,
    required this.startDateTime,
    required this.endDateTime,
    required this.minAge,
    required this.maxAge,
    required this.experienceRequired,
    this.insuranceRequired = false,
    this.sector,
    this.duties,
    this.dressCode,
  });

  final String categoryId;
  final String title;
  final String description;
  final String position;
  final CreateJobAddress address;
  final JobType type;
  final SalaryType salaryType;
  final double salary;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final int minAge;
  final int maxAge;
  final bool experienceRequired;
  final bool insuranceRequired;
  final String? sector;
  final String? duties;
  final String? dressCode;

  /// [forCompany] `false` iken `insuranceRequired` düşüyor: bireysel uç o
  /// alanı tanımıyor ve fazladan alan gönderince istek reddedilebiliyor.
  Map<String, dynamic> toJson({required bool forCompany}) => {
    'categoryId': categoryId,
    'title': title,
    'description': description,
    'sector': ?sector,
    'position': position,
    'duties': ?duties,
    'address': address.toJson(),
    'type': type.code,
    'salaryType': salaryType.code,
    'salary': salary,
    // Backend `LocalDateTime` bekliyor: saat dilimi eki olmadan, yerel saat.
    'startDateTime': _localIso(startDateTime),
    'endDateTime': _localIso(endDateTime),
    'minAge': minAge,
    'maxAge': maxAge,
    'experienceRequired': experienceRequired,
    if (forCompany) 'insuranceRequired': insuranceRequired,
    'dressCode': ?dressCode,
  };

  static String _localIso(DateTime value) =>
      value.toLocal().toIso8601String().split('.').first;
}
