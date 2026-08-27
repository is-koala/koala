import 'package:koala/employee/features/home/models/job.dart';

/// Testlerde kullanılan hazır [Job] üreticisi.
///
/// `Job` sekiz zorunlu alan istiyor; her testte hepsini tekrar yazmak testin
/// asıl konusunu gölgeliyor. Sadece o testin önemsediği alan geçilsin diye
/// geri kalanına makul varsayılanlar veriliyor.
Job buildJob({
  String id = 'job_1',
  String title = 'Part-time Garson',
  String subtitle = 'Hafta sonu çalışacak garson aranıyor.',
  double price = 800,
  JobType type = JobType.oneTime,
  JobCategory category = JobCategorySeeds.waiter,
  double latitude = 39.9208,
  double longitude = 32.8541,
  String? company = 'Koala Cafe',
  String? description,
  String? address = 'Kızılay, Ankara',
}) {
  return Job(
    id: id,
    latitude: latitude,
    longitude: longitude,
    type: type,
    category: category,
    title: title,
    subtitle: subtitle,
    price: price,
    company: company,
    description: description,
    address: address,
  );
}
