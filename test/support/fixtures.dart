import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';

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
  );
}
