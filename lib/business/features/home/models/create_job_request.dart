import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/models/canonical_address.dart';

/// Yeni ilan gövdesi; bireysel ve şirket ucu aynı modeli kullanıyor. Fark
/// [insuranceRequired] ve [addressPublic]: bireysel uç ikisini tanımıyor.
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
    this.addressPublic = true,
    this.sector,
    this.duties,
    this.dressCode,
  });

  final String categoryId;
  final String title;
  final String description;
  final String position;
  final AddressWrite address;
  final JobType type;
  final SalaryType salaryType;

  /// Dize gönderilir ki teklif alınan değer IEEE-754 dönüşümüne uğramasın.
  final String salary;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final int minAge;
  final int maxAge;
  final bool experienceRequired;
  final bool insuranceRequired;

  /// Şirket ilanının tam konumu herkese açık mı. Kapalıyken ilan yaklaşık
  /// konumla görünür; kat, daire ve tarif her durumda yalnız ilan sahibine ve
  /// atanan çalışana gider. Sunucu varsayılanı `true` ama alan her zaman açıkça
  /// yazılıyor ki varsayılan değişince form sessizce başka şey yapmasın.
  final bool addressPublic;
  final String? sector;
  final String? duties;
  final String? dressCode;

  /// Bireysel istekte `insuranceRequired` ve `addressPublic` düşer; bireysel
  /// ilanın konumu her zaman yaklaşık.
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
    'startDateTime': _localIso(startDateTime),
    'endDateTime': _localIso(endDateTime),
    'minAge': minAge,
    'maxAge': maxAge,
    'experienceRequired': experienceRequired,
    if (forCompany) 'insuranceRequired': insuranceRequired,
    if (forCompany) 'addressPublic': addressPublic,
    'dressCode': ?dressCode,
  };

  static String _localIso(DateTime value) =>
      value.toLocal().toIso8601String().split('.').first;
}
