import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/product/models/canonical_address.dart';

/// Testlerde kullanılan hazır [Job] üreticisi.
///
/// `Job` sekiz zorunlu alan istiyor; her testte hepsini tekrar yazmak testin
/// asıl konusunu gölgeliyor. Sadece o testin önemsediği alan geçilsin diye
/// geri kalanına makul varsayılanlar veriliyor.
Job buildJob({
  String id = 'job_1',
  String title = 'Part-time Garson',
  String? position = 'Hafta sonu garson',
  String? sector,
  double price = 800,
  JobType type = JobType.oneTime,
  JobCategory category = JobCategorySeeds.waiter,
  JobEmployerType employerType = JobEmployerType.company,
  SalaryType salaryType = SalaryType.daily,
  JobStatus status = JobStatus.open,
  double? latitude = 39.9208,
  double? longitude = 32.8541,
  String? company = 'Koala Cafe',
  String? cityName = 'Ankara',
  String? districtName = 'Kızılay',
  bool insuranceRequired = false,
  bool experienceRequired = false,
  DateTime? startDateTime,
  DateTime? endDateTime,
  String? coverImageUrl,
  AddressPrecision addressPrecision = AddressPrecision.approximate,
}) {
  return Job(
    id: id,
    title: title,
    position: position,
    sector: sector,
    price: price,
    type: type,
    category: category,
    employerType: employerType,
    salaryType: salaryType,
    status: status,
    latitude: latitude,
    longitude: longitude,
    company: company,
    cityName: cityName,
    districtName: districtName,
    insuranceRequired: insuranceRequired,
    experienceRequired: experienceRequired,
    startDateTime: startDateTime,
    endDateTime: endDateTime,
    coverImageUrl: coverImageUrl,
    addressPrecision: addressPrecision,
  );
}

/// Testlerde kullanılan hazır [JobDetail] üreticisi.
JobDetail buildJobDetail({
  String id = 'job_1',
  String title = 'Part-time Garson',
  JobCategory category = JobCategorySeeds.waiter,
  JobType type = JobType.oneTime,
  JobEmployerType employerType = JobEmployerType.company,
  SalaryType salaryType = SalaryType.daily,
  double price = 800,
  JobStatus status = JobStatus.open,
  String? description = 'Hafta sonu çalışacak garson aranıyor.',
  String? duties,
  String? position = 'Hafta sonu garson',
  String? sector,
  String? dressCode,
  int? minAge,
  int? maxAge,
  JobCompany? company,
  JobCreator? creator,
  CanonicalAddress? address,
  AddressPrecision addressPrecision = AddressPrecision.approximate,
}) {
  return JobDetail(
    id: id,
    title: title,
    category: category,
    type: type,
    employerType: employerType,
    salaryType: salaryType,
    price: price,
    status: status,
    description: description,
    duties: duties,
    position: position,
    sector: sector,
    dressCode: dressCode,
    minAge: minAge,
    maxAge: maxAge,
    company: company,
    creator: creator,
    address: address,
    addressPrecision: addressPrecision,
  );
}

/// Sunucunun `EXACT` yanıtta gönderdiği koordinat: **tam hassasiyetli**,
/// yuvarlama yok.
///
/// Fikstürün ondalıkları burada önemli. Yuvarlanmış bir koordinatla kurulan
/// `EXACT` durumu, yalnız o dalda kesin değeri sızdıran bir hatayı göremezdi:
/// iki dal da aynı sayıyı taşırdı.
const double exactLatitude = 41.015137;
const double exactLongitude = 28.979530;

/// Yetkisiz görüntüleyenin gördüğü koordinat: sunucu iki ondalığa yuvarlıyor.
const double roundedLatitude = 41.02;
const double roundedLongitude = 28.98;

/// Aynı ilanın **yetkili** görünümü: kesin koordinat, `EXACT` bayrağı.
///
/// İsim aktör saymıyor, bilerek. Aktör → kesinlik eşlemesini **sunucu**
/// kuruyor (`JobAddressVisibility`); mobilde onu bağlayan hiçbir şey yok. Bu
/// yüzden istemci tarafında ölçülebilen tek şey iki durum: sunucu kesin verdi,
/// ya da vermedi. "İşveren", "atanmış çalışan", "anonim ziyaretçi" diye dört
/// isim koymak, testin ölçmediği bir eşlemeyi ölçüyormuş gibi gösterirdi.
Job exactView() => buildJob(
  id: 'job_ayni',
  latitude: exactLatitude,
  longitude: exactLongitude,
  addressPrecision: AddressPrecision.exact,
);

/// Aynı ilanın **yetkisiz** görünümü: yuvarlanmış koordinat, `APPROXIMATE`.
Job maskedView() => buildJob(
  id: 'job_ayni',
  latitude: roundedLatitude,
  longitude: roundedLongitude,
  addressPrecision: AddressPrecision.approximate,
);
