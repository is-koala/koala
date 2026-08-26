import 'package:koala/employee/features/jobs/models/my_job.dart';

class MyJobsService {
  static final MyJobsService _instance = MyJobsService._internal();
  factory MyJobsService() => _instance;
  MyJobsService._internal();

  Future<List<MyJob>> getMyJobs() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _fakeJobs;
  }

  Future<List<MyJob>> getJobsByStatus(MyJobStatus status) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _fakeJobs.where((job) => job.status == status).toList();
  }

  final List<MyJob> _fakeJobs = const [
    // Pending - Başvuru bekleyenler
    MyJob(
      id: '1',
      title: 'Düğün Fotoğrafçısı',
      company: 'Özlem & Murat Düğün Organizasyonu',
      companyId: 'comp_1',
      description: 'Düğün töreni fotoğraf çekimi, 6 saat',
      date: '15.03.2026',
      price: 3500,
      status: MyJobStatus.pending,
    ),
    MyJob(
      id: '2',
      title: 'Cafe Barista',
      company: 'Kahve Durağı Cafe',
      companyId: 'comp_2',
      description: 'Hafta sonu barista, sabah vardiyası',
      date: '12.03.2026',
      price: 1200,
      status: MyJobStatus.pending,
    ),
    MyJob(
      id: '3',
      title: 'Kedi Bakıcısı',
      company: 'Ahmet Yılmaz (Bireysel)',
      companyId: 'comp_3',
      description: '3 gün boyunca 2 kedi bakımı',
      date: '18.03.2026',
      price: 900,
      status: MyJobStatus.pending,
    ),

    // Approved - Onaylanmış, gidilmesi beklenen
    MyJob(
      id: '4',
      title: 'Ürün Fotoğrafçısı',
      company: 'TrendShop E-ticaret',
      companyId: 'comp_6',
      description: '50 ürün için stüdyo çekimi',
      date: '08.03.2026',
      price: 2800,
      status: MyJobStatus.approved,
    ),
    MyJob(
      id: '5',
      title: 'Garson',
      company: 'Lezzet Durağı Restaurant',
      companyId: 'comp_4',
      description: 'Akşam vardiyası, özel davet servisi',
      date: '07.03.2026',
      price: 1500,
      status: MyJobStatus.approved,
    ),

    // Completed - İş bitti, ödeme bekleniyor
    MyJob(
      id: '6',
      title: 'Etkinlik Fotoğrafçısı',
      company: 'Elit Organizasyon',
      companyId: 'comp_7',
      description: 'Kurumsal lansman etkinliği çekimi',
      date: '01.03.2026',
      price: 4000,
      status: MyJobStatus.completed,
    ),
    MyJob(
      id: '7',
      title: 'Logo Tasarımcısı',
      company: 'FitLife Spor Salonu',
      companyId: 'comp_9',
      description: 'Startup için logo ve marka kimliği',
      date: '28.02.2026',
      price: 2200,
      status: MyJobStatus.completed,
    ),

    // Past - Tamamlanmış ve ödemesi alınmış
    MyJob(
      id: '8',
      title: 'Düğün Fotoğrafçısı',
      company: 'Özlem & Murat Düğün Organizasyonu',
      companyId: 'comp_1',
      description: 'Kır düğünü fotoğraf ve video çekimi',
      date: '20.02.2026',
      price: 5000,
      status: MyJobStatus.past,
    ),
    MyJob(
      id: '9',
      title: 'Barista',
      company: 'Coffee Break Cafe',
      companyId: 'comp_10',
      description: 'Özel etkinlik için barista hizmeti',
      date: '14.02.2026',
      price: 1800,
      status: MyJobStatus.past,
    ),
    MyJob(
      id: '10',
      title: 'Garson',
      company: 'Elit Organizasyon',
      companyId: 'comp_7',
      description: 'Gala yemeği servis hizmeti',
      date: '10.02.2026',
      price: 1600,
      status: MyJobStatus.past,
    ),
    MyJob(
      id: '11',
      title: 'Köpek Gezdirici',
      company: 'Zeynep Kaya (Bireysel)',
      companyId: 'comp_8',
      description: '1 hafta Golden Retriever bakımı',
      date: '05.02.2026',
      price: 2100,
      status: MyJobStatus.past,
    ),
    MyJob(
      id: '12',
      title: 'Ürün Fotoğrafçısı',
      company: 'TrendShop E-ticaret',
      companyId: 'comp_6',
      description: 'Sezon kataloğu için 100 ürün çekimi',
      date: '28.01.2026',
      price: 5500,
      status: MyJobStatus.past,
    ),
    MyJob(
      id: '13',
      title: 'Sosyal Medya Tasarımcısı',
      company: 'FitLife Spor Salonu',
      companyId: 'comp_9',
      description: 'Instagram içerik tasarımı, 30 görsel',
      date: '20.01.2026',
      price: 3000,
      status: MyJobStatus.past,
    ),
  ];
}
