import 'package:flutter/material.dart';
import 'package:koala/business/features/home/services/fake_business_company.dart';
import 'package:koala/business/features/home/models/b_applicant.dart';
import 'package:koala/business/features/home/models/b_job_post.dart';
import 'package:koala/employee/features/home/models/job.dart';
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
        job: Job(
          id: 'b_1',
          latitude: 39.9208,
          longitude: 32.8541,
          type: JobType.recurring,
          category: JobCategory.waiter,
          title: 'Part-time Garson',
          subtitle:
              'Kızılay\'da cafe\'de hafta sonu çalışacak garson aranıyor.',
          price: 800,
          company: companyName,
          description:
              'Kızılay merkezde bulunan cafe\'mizde hafta sonları çalışacak enerjik ve güler yüzlü garson arkadaşlar arıyoruz.',
          sector: 'Restoran & Cafe',
          position: 'Garson',
          duties:
              'Müşteri karşılama, sipariş alma, servis yapma, kasa işlemleri',
          insuranceRequired: false,
          startDateTime: DateTime(2026, 3, 10, 9, 0),
          endDateTime: DateTime(2026, 3, 10, 18, 0),
          salaryType: 'HOURLY',
          minAge: 18,
          maxAge: 35,
          experienceRequired: false,
          dressCode: 'Siyah pantolon, beyaz gömlek',
          employerType: 'COMPANY',
          address: 'Kızılay, Ankara',
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
        job: Job(
          id: 'b_2',
          latitude: 39.9208,
          longitude: 32.8541,
          type: JobType.recurring,
          category: JobCategory.barista,
          title: 'Deneyimli Barista',
          subtitle: 'Specialty coffee deneyimi olan barista aranıyor.',
          price: 15000,
          company: companyName,
          description:
              'Specialty coffee alanında deneyimli, latte art yapabilen barista aranıyor. Tam zamanlı pozisyon.',
          sector: 'Cafe & Coffee Shop',
          position: 'Barista',
          duties:
              'Kahve hazırlama, latte art, müşteri iletişimi, stok kontrolü',
          insuranceRequired: true,
          startDateTime: DateTime(2026, 3, 15, 8, 0),
          endDateTime: DateTime(2026, 3, 15, 17, 0),
          salaryType: 'FIXED',
          minAge: 20,
          maxAge: 40,
          experienceRequired: true,
          dressCode: 'Cafe önlüğü sağlanacak',
          employerType: 'COMPANY',
          address: 'Kızılay, Ankara',
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
        job: Job(
          id: 'b_3',
          latitude: 39.9208,
          longitude: 32.8541,
          type: JobType.oneTime,
          category: JobCategory.photography,
          title: 'Mekan Fotoğrafçısı',
          subtitle: 'Cafe\'nin profesyonel fotoğrafları çekilecek.',
          price: 2000,
          company: companyName,
          description:
              'Cafe\'mizin sosyal medya hesapları ve web sitesi için profesyonel mekan fotoğrafları çekilecektir.',
          sector: 'Fotoğrafçılık',
          position: 'Mekan Fotoğrafçısı',
          duties:
              'İç mekan fotoğrafları, ürün fotoğrafları, sosyal medya görselleri',
          insuranceRequired: false,
          startDateTime: DateTime(2026, 2, 15, 10, 0),
          endDateTime: DateTime(2026, 2, 15, 16, 0),
          salaryType: 'FIXED',
          minAge: 18,
          maxAge: 50,
          experienceRequired: true,
          dressCode: 'Serbest',
          employerType: 'COMPANY',
          address: 'Kızılay, Ankara',
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

  /// Yeni iş ilanı oluştur
  void createJobPost(Job job) {
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

  /// Çalışan tarafından gelen başvuruları kontrol et ve eşleştir
  void syncApplicantsFromApplyProvider(ApplyProvider applyProvider) {
    final appliedJobs = applyProvider.appliedJobs;
    final fakeUser = FakeUser.instance;

    for (final applied in appliedJobs) {
      // "applied_" prefix'ini kaldırarak orijinal job id'yi bul
      final originalJobId = applied.id.replaceFirst('applied_', '');

      final postIndex = _jobPosts.indexWhere((p) => p.job.id == originalJobId);
      if (postIndex == -1) continue;

      final post = _jobPosts[postIndex];
      final alreadyExists = post.applicants.any(
        (a) => a.id == 'sync_${applied.id}',
      );

      if (!alreadyExists) {
        final newApplicant = BApplicant(
          id: 'sync_${applied.id}',
          fullName: fakeUser.fullName,
          jobTitle: fakeUser.jobTitle,
          profileImage: fakeUser.profileImage,
          appliedDate: applied.date,
        );

        _jobPosts[postIndex] = post.copyWith(
          applicants: [...post.applicants, newApplicant],
        );
      }
    }
    notifyListeners();
  }
}
