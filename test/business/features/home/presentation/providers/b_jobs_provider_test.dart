import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/b_applicant.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/services/job_application_service.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/fixtures.dart';

void main() {
  late BJobsProvider provider;

  setUp(() => provider = BJobsProvider());

  group('başlangıç verisi', () {
    test('aktif ve geçmiş ilanlar ayrışıyor', () {
      expect(provider.allPosts, isNotEmpty);
      expect(provider.activePosts.every((p) => p.isActive), isTrue);
      expect(provider.pastPosts.every((p) => !p.isActive), isTrue);
      expect(
        provider.activePosts.length + provider.pastPosts.length,
        provider.allPosts.length,
      );
    });

    test('ilan id\'leri benzersiz', () {
      final ids = provider.allPosts.map((p) => p.job.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('allPosts dışarıdan değiştirilemez', () {
      expect(() => provider.allPosts.clear(), throwsUnsupportedError);
    });
  });

  group('createJobPost', () {
    test('yeni ilan aktif olarak listenin başına eklenir', () {
      final before = provider.allPosts.length;

      provider.createJobPost(buildJobDetail(id: 'yeni_1', title: 'Yeni İlan'));

      expect(provider.allPosts, hasLength(before + 1));
      final created = provider.allPosts.first;
      expect(created.job.id, 'yeni_1');
      expect(created.isActive, isTrue);
      expect(created.applicants, isEmpty);
    });
  });

  group('deactivatePost', () {
    test('ilanı geçmişe taşır', () {
      final id = provider.activePosts.first.job.id;

      provider.deactivatePost(id);

      expect(provider.getPostByJobId(id)!.isActive, isFalse);
      expect(provider.pastPosts.map((p) => p.job.id), contains(id));
    });

    test('olmayan id listeyi bozmaz', () {
      final before = provider.allPosts.length;

      provider.deactivatePost('yok_boyle_bir_id');

      expect(provider.allPosts, hasLength(before));
    });
  });

  group('deletePost', () {
    test('ilanı siler', () {
      final id = provider.allPosts.first.job.id;
      final before = provider.allPosts.length;

      provider.deletePost(id);

      expect(provider.allPosts, hasLength(before - 1));
      expect(provider.getPostByJobId(id), isNull);
    });
  });

  group('başvuru yönetimi', () {
    const applicant = BApplicant(
      id: 'aday_1',
      fullName: 'Test Aday',
      jobTitle: 'Garson',
      profileImage: 'assets/images/koala_profile_picture.png',
      appliedDate: '01.01.2026',
    );

    test('approveApplicant ilanı kapatır ve çalışanı atar', () {
      final post = provider.activePosts.firstWhere(
        (p) => p.applicants.isNotEmpty,
      );

      provider.approveApplicant(post.job.id, applicant);

      final updated = provider.getPostByJobId(post.job.id)!;
      expect(updated.isActive, isFalse);
      expect(updated.worker?.id, 'aday_1');
      // Biri işe alındıysa diğer başvurular anlamsız kalıyor.
      expect(updated.applicants, isEmpty);
    });

    test('rejectApplicant yalnızca o adayı çıkarır', () {
      final post = provider.activePosts.firstWhere(
        (p) => p.applicants.length > 1,
      );
      final reddedilen = post.applicants.first.id;
      final kalan = post.applicants.map((a) => a.id).skip(1).toList();

      provider.rejectApplicant(post.job.id, reddedilen);

      final updated = provider.getPostByJobId(post.job.id)!;
      expect(updated.applicants.map((a) => a.id), kalan);
      expect(updated.isActive, isTrue);
    });
  });

  group('syncApplicantsFromApplyProvider', () {
    /// Başvurusu sunucudan gelmiş gibi doldurulmuş bir sağlayıcı.
    Future<ApplyProvider> applyProviderFor(String jobId) async {
      final api = FakeApi(
        handler: (_) => FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'content': [
                {
                  'id': 'app_$jobId',
                  'status': 'APPLIED',
                  'applicationDateTime': '2026-03-05T10:00:00Z',
                  'job': {
                    'id': jobId,
                    'title': 'Başvurulan İlan',
                    'category': {
                      'id': 'c',
                      'code': 'WAITER',
                      'name': 'Garsonluk',
                    },
                    'salary': 500,
                  },
                },
              ],
            },
          },
        ),
      );

      final applyProvider = ApplyProvider(
        service: JobApplicationService.withClient(api.client),
      );
      await applyProvider.load();
      return applyProvider;
    }

    test('çalışan tarafındaki başvuru işveren listesine düşer', () async {
      final post = provider.activePosts.first;
      final oncekiAdaySayisi = post.applicants.length;

      final applyProvider = await applyProviderFor(post.job.id);
      provider.syncApplicantsFromApplyProvider(applyProvider);

      final updated = provider.getPostByJobId(post.job.id)!;
      expect(updated.applicants, hasLength(oncekiAdaySayisi + 1));
      expect(
        updated.applicants.map((a) => a.id),
        contains('sync_app_${post.job.id}'),
      );
      expect(
        updated.applicants.last.appliedDate,
        '05.03.2026',
        reason: 'başvuru tarihi sunucudan gelen değerden biçimlenmeli',
      );
    });

    test('ikinci senkron kopya aday üretmez', () async {
      final post = provider.activePosts.first;
      final applyProvider = await applyProviderFor(post.job.id);

      provider.syncApplicantsFromApplyProvider(applyProvider);
      final ilkSayi = provider.getPostByJobId(post.job.id)!.applicants.length;
      provider.syncApplicantsFromApplyProvider(applyProvider);

      expect(
        provider.getPostByJobId(post.job.id)!.applicants,
        hasLength(ilkSayi),
      );
    });

    test('işverene ait olmayan ilana yapılan başvuru yok sayılır', () async {
      final before = provider.allPosts.map((p) => p.applicants.length).toList();

      final applyProvider = await applyProviderFor('baska_firmanin_ilani');
      provider.syncApplicantsFromApplyProvider(applyProvider);

      expect(
        provider.allPosts.map((p) => p.applicants.length).toList(),
        before,
      );
    });
  });
}
