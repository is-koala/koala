import 'package:flutter/material.dart';
import 'package:koala/business/features/home/services/fake_business_company.dart';
import 'package:koala/business/features/home/models/b_applicant.dart';
import 'package:koala/business/features/home/models/b_job_post.dart';
import 'package:koala/employee/features/auth/models/user_address.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/profile/services/fake_user.dart';

/// İşveren tarafında iş ilanlarını yöneten provider.
/// - Yeni ilan oluşturma
/// - Aktif / Geçmiş ilanları listeleme
/// - Çalışan tarafındaki ApplyProvider ile bağlantı (başvuranlar)
class BJobsProvider extends ChangeNotifier {
  final List<BJobPost> _jobPosts = [];

  BJobsProvider() {
    _loadInitialJobs();
  }

  /// Fake başlangıç verileri
  void _loadInitialJobs() {
    final companyName = FakeBusinessCompany.instance.name;

    _jobPosts.addAll([
      BJobPost(
        job: JobDetail(
          status: JobStatus.open,
          id: 'b_1',
          type: JobType.recurring,
          category: JobCategorySeeds.waiter,
          title: 'Part-time Garson',
          price: 800,
          company: JobCompany(id: 'b_company', name: companyName),
          description:
              'Kızılay merkezde bulunan cafe\'mizde hafta sonları çalışacak enerjik ve güler yüzlü garson arkadaşlar arıyoruz.',
          sector: 'Restoran & Cafe',
          position: 'Garson',
          duties:
              'Müşteri karşılama, sipariş alma, servis yapma, kasa işlemleri',
          insuranceRequired: false,
          startDateTime: DateTime(2026, 3, 10, 9, 0),
          endDateTime: DateTime(2026, 3, 10, 18, 0),
          salaryType: SalaryType.hourly,
          minAge: 18,
          maxAge: 35,
          experienceRequired: false,
          dressCode: 'Siyah pantolon, beyaz gömlek',
          employerType: JobEmployerType.company,
          address: const UserAddress(
            id: 'b_address',
            addressLine: 'Kızılay, Ankara',
          ),
        ),
        isActive: true,
        createdAt: DateTime(2026, 3, 1),
        applicants: [
          BApplicant(
            id: 'applicant_1',
            fullName: 'Yakup Demir',
            jobTitle: 'Fotoğrafçı',
            profileImage: 'assets/images/koala_profile_picture.png',
            appliedDate: '05.03.2026',
            coverLetter:
                'Merhaba, cafe deneyimim var ve hafta sonları uygunumdur.',
          ),
        ],
      ),
      BJobPost(
        job: JobDetail(
          status: JobStatus.open,
          id: 'b_2',
          type: JobType.recurring,
          category: JobCategorySeeds.barista,
          title: 'Deneyimli Barista',
          price: 15000,
          company: JobCompany(id: 'b_company', name: companyName),
          description:
              'Specialty coffee alanında deneyimli, latte art yapabilen barista aranıyor. Tam zamanlı pozisyon.',
          sector: 'Cafe & Coffee Shop',
          position: 'Barista',
          duties:
              'Kahve hazırlama, latte art, müşteri iletişimi, stok kontrolü',
          insuranceRequired: true,
          startDateTime: DateTime(2026, 3, 15, 8, 0),
          endDateTime: DateTime(2026, 3, 15, 17, 0),
          salaryType: SalaryType.daily,
          minAge: 20,
          maxAge: 40,
          experienceRequired: true,
          dressCode: 'Cafe önlüğü sağlanacak',
          employerType: JobEmployerType.company,
          address: const UserAddress(
            id: 'b_address',
            addressLine: 'Kızılay, Ankara',
          ),
        ),
        isActive: true,
        createdAt: DateTime(2026, 3, 3),
        applicants: [
          BApplicant(
            id: 'applicant_2',
            fullName: 'Ayşe Yılmaz',
            jobTitle: 'Barista',
            profileImage: 'assets/images/koala_profile_picture.png',
            appliedDate: '06.03.2026',
            coverLetter: '3 yıldır specialty coffee alanında çalışıyorum.',
          ),
          BApplicant(
            id: 'applicant_3',
            fullName: 'Mehmet Kaya',
            jobTitle: 'Barista / Garson',
            profileImage: 'assets/images/koala_profile_picture.png',
            appliedDate: '07.03.2026',
          ),
        ],
      ),
      // Geçmiş ilan
      BJobPost(
        job: JobDetail(
          status: JobStatus.open,
          id: 'b_3',
          type: JobType.oneTime,
          category: JobCategorySeeds.photography,
          title: 'Mekan Fotoğrafçısı',
          price: 2000,
          company: JobCompany(id: 'b_company', name: companyName),
          description:
              'Cafe\'mizin sosyal medya hesapları ve web sitesi için profesyonel mekan fotoğrafları çekilecektir.',
          sector: 'Fotoğrafçılık',
          position: 'Mekan Fotoğrafçısı',
          duties:
              'İç mekan fotoğrafları, ürün fotoğrafları, sosyal medya görselleri',
          insuranceRequired: false,
          startDateTime: DateTime(2026, 2, 15, 10, 0),
          endDateTime: DateTime(2026, 2, 15, 16, 0),
          salaryType: SalaryType.daily,
          minAge: 18,
          maxAge: 50,
          experienceRequired: true,
          dressCode: 'Serbest',
          employerType: JobEmployerType.company,
          address: const UserAddress(
            id: 'b_address',
            addressLine: 'Kızılay, Ankara',
          ),
        ),
        isActive: false,
        createdAt: DateTime(2026, 2, 1),
        worker: const BApplicant(
          id: 'applicant_4',
          fullName: 'Burak Şen',
          jobTitle: 'Fotoğrafçı',
          profileImage: 'assets/images/koala_profile_picture.png',
          appliedDate: '03.02.2026',
        ),
      ),
    ]);
  }

  /// Tüm ilanlar
  List<BJobPost> get allPosts => List.unmodifiable(_jobPosts);

  /// Aktif ilanlar
  List<BJobPost> get activePosts => _jobPosts.where((p) => p.isActive).toList();

  /// Geçmiş ilanlar
  List<BJobPost> get pastPosts => _jobPosts.where((p) => !p.isActive).toList();

  static String _formatApplicationDate(DateTime? value) {
    if (value == null) return '';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  /// Yeni iş ilanı oluştur
  void createJobPost(JobDetail job) {
    final post = BJobPost(
      job: job,
      isActive: true,
      applicants: [],
      createdAt: DateTime.now(),
    );
    _jobPosts.insert(0, post);
    notifyListeners();
  }

  /// İlanı geçmişe taşı (pasif yap)
  void deactivatePost(String jobId) {
    final index = _jobPosts.indexWhere((p) => p.job.id == jobId);
    if (index != -1) {
      _jobPosts[index] = _jobPosts[index].copyWith(isActive: false);
      notifyListeners();
    }
  }

  /// İlanı sil
  void deletePost(String jobId) {
    _jobPosts.removeWhere((p) => p.job.id == jobId);
    notifyListeners();
  }

  /// Başvuranı onayla — ilanı geçmişe taşır ve worker olarak atar
  void approveApplicant(String jobId, BApplicant applicant) {
    final index = _jobPosts.indexWhere((p) => p.job.id == jobId);
    if (index != -1) {
      _jobPosts[index] = _jobPosts[index].copyWith(
        isActive: false,
        worker: applicant,
        applicants: [],
      );
      notifyListeners();
    }
  }

  /// Başvuranı reddet — listeden çıkar
  void rejectApplicant(String jobId, String applicantId) {
    final index = _jobPosts.indexWhere((p) => p.job.id == jobId);
    if (index != -1) {
      final updated = _jobPosts[index].applicants
          .where((a) => a.id != applicantId)
          .toList();
      _jobPosts[index] = _jobPosts[index].copyWith(applicants: updated);
      notifyListeners();
    }
  }

  /// Belirli bir ilanı getir
  BJobPost? getPostByJobId(String jobId) {
    try {
      return _jobPosts.firstWhere((p) => p.job.id == jobId);
    } catch (_) {
      return null;
    }
  }

  /// Çalışan tarafında yapılan başvuruları işverenin aday listesine yansıtır.
  ///
  /// TODO(backend): Bu bir demo köprüsü. İşverenin gerçek aday listesi
  /// `GET /jobs/{jobId}/applications`'tan gelecek; o bağlandığında bu metot
  /// tamamen kalkacak.
  void syncApplicantsFromApplyProvider(ApplyProvider applyProvider) {
    final fakeUser = FakeUser.instance;

    for (final application in applyProvider.applications) {
      final postIndex = _jobPosts.indexWhere(
        (p) => p.job.id == application.job.id,
      );
      if (postIndex == -1) continue;

      final post = _jobPosts[postIndex];
      final alreadyExists = post.applicants.any(
        (a) => a.id == 'sync_${application.id}',
      );

      if (!alreadyExists) {
        final newApplicant = BApplicant(
          id: 'sync_${application.id}',
          fullName: fakeUser.fullName,
          jobTitle: fakeUser.jobTitle,
          profileImage: fakeUser.profileImage,
          appliedDate: _formatApplicationDate(application.applicationDateTime),
        );

        _jobPosts[postIndex] = post.copyWith(
          applicants: [...post.applicants, newApplicant],
        );
      }
    }
    notifyListeners();
  }
}
