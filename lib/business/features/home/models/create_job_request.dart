import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/models/canonical_address.dart';

/// Yeni ilan isteğinin gövdesi.
///
/// İki uca da aynı model gidiyor: `POST /users/me/jobs` (bireysel) ve
/// `POST /companies/{id}/jobs` (kurumsal). Fark iki alan:
/// [insuranceRequired] ve [addressPublic] — `CreateIndividualJobDto` ikisini
/// de taşımıyor, o yüzden bireysel istekte gönderilmiyorlar (bkz. [toJson]).
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

  /// JSON'da dize gönderilir; backend `BigDecimal` olarak okur. Böylece
  /// teklif alınan değer IEEE-754 dönüşümüne uğramadan snapshot'a taşınır.
  final String salary;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final int minAge;
  final int maxAge;
  final bool experienceRequired;
  final bool insuranceRequired;

  /// Şirket ilanının tam konumu (kesin pin, sokak ve bina) herkese açık mı.
  ///
  /// Kural sunucuda (Yusuf, 04.11.2026): şirket ilanında tam konum varsayılan
  /// olarak açık, işveren "Adresi gizle" ile kapatabiliyor; kapalıyken ilan
  /// herkese yaklaşık konumla görünüyor. Kat, daire ve tarif bu alandan
  /// bağımsız olarak yalnız ilan sahibine ve atanan çalışana gidiyor.
  /// Sunucu alan gelmezse `true` sayıyor; yine de şirket isteğinde her zaman
  /// açıkça yazılıyor ki varsayılanın sunucuda değişmesi formu sessizce
  /// başka bir şey yapar hâle getirmesin.
  final bool addressPublic;
  final String? sector;
  final String? duties;
  final String? dressCode;

  /// [forCompany] `false` iken `insuranceRequired` ve `addressPublic`
  /// düşüyor: bireysel uç bu alanları tanımıyor ve fazladan alan gönderince
  /// istek reddedilebiliyor. Bireysel ilanın konumu her zaman herkese
  /// yaklaşık; bunu işveren seçmiyor.
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
    if (forCompany) 'addressPublic': addressPublic,
    'dressCode': ?dressCode,
  };

  static String _localIso(DateTime value) =>
      value.toLocal().toIso8601String().split('.').first;
}
