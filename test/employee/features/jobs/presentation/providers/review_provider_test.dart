import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/review_fixtures.dart';
import '../../../../../support/work_test_support.dart';

FakeApi createdApi({String? jobAssignmentId}) => FakeApi(
  handler: (request) {
    final body = request.data as Map<String, dynamic>;
    return reviewCreatedResponse(
      reviewDtoJson(
        rating: body['rating'] as int,
        comment: body['comment'] as String?,
        jobAssignmentId: jobAssignmentId,
      ),
    );
  },
);

FakeApi alreadyReviewedApi() =>
    FakeApi(handler: (_) => reviewAlreadyReviewedResponse());

FakeApi workNotCompletedApi() =>
    FakeApi(handler: (_) => reviewWorkNotCompletedResponse());

ReviewProvider providerWith(FakeApi api) =>
    ReviewProvider(service: ReviewService.withClient(api.client));

/// Sunucudan gelmiş bir atama; [myReview] verilirse sunucu "değerlendirdin"
/// diyor.
Assignment assignmentWith({
  String id = 'asg_1',
  Map<String, Object?>? myReview,
  bool? counterpartyReviewed,
}) => Assignment.fromJson(
  assignmentJson(
    id: id,
    status: 'COMPLETED',
    extra: {
      'myReview': ?myReview,
      'counterpartyReviewed': ?counterpartyReviewed,
    },
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ReviewProvider sunucu durumu', () {
    // Kaynak sunucu: `myReview` doluysa değerlendirilmiş, içerik oradan.
    test('myReview dolu atama değerlendirilmiş, içerik sunucudan', () {
      final provider = providerWith(createdApi());
      final assignment = assignmentWith(
        myReview: {
          'id': 'rev_9',
          'rating': 4,
          'comment': 'İyi',
          'createdAt': '2026-09-11T09:00:00Z',
        },
      );

      expect(provider.hasReviewed(assignment), isTrue);
      expect(provider.ownReviewFor(assignment)?.summaryLabel, '★4 · "İyi"');
    });

    test('myReview null atama değerlendirilmemiş', () {
      final provider = providerWith(createdApi());

      expect(provider.hasReviewed(assignmentWith()), isFalse);
      expect(provider.ownReviewFor(assignmentWith()), isNull);
    });

    test('atama yoksa (başvuru satırı) değerlendirilmiş sayılmaz', () {
      final provider = providerWith(createdApi());

      expect(provider.hasReviewed(null), isFalse);
      expect(provider.ownReviewFor(null), isNull);
    });
  });

  group('ReviewProvider.submitReview', () {
    test(
      'başarılı gönderim atamayı oturumluk işaretler, içerik yanıttan',
      () async {
        final provider = providerWith(createdApi());

        final sent = await provider.submitReview(
          assignmentId: 'asg_1',
          rating: 4,
          comment: 'Dakik ve titiz.',
        );

        expect(sent, isTrue);
        expect(provider.errorMessage, isNull);
        // Liste henüz tazelenmedi (`myReview` yok); provider boşluğu kapatıyor.
        final stale = assignmentWith();
        expect(provider.hasReviewed(stale), isTrue);
        expect(
          provider.ownReviewFor(stale)?.summaryLabel,
          '★4 · "Dakik ve titiz."',
        );
        expect(provider.hasReviewed(assignmentWith(id: 'asg_2')), isFalse);
      },
    );

    // Yanıt hangi atamaya yazıldığını söylüyor (`jobAssignmentId`, yalnız
    // POST yanıtında dolu); anahtar o, istenen kimlik değil.
    test('yanıttaki jobAssignmentId anahtar olarak esas alınır', () async {
      final provider = providerWith(createdApi(jobAssignmentId: 'asg_server'));

      await provider.submitReview(assignmentId: 'asg_1', rating: 5);

      expect(provider.hasReviewed(assignmentWith(id: 'asg_server')), isTrue);
      expect(provider.hasReviewed(assignmentWith(id: 'asg_1')), isFalse);
    });

    // Sonraki fetch sunucuyu esas alıyor: yeni gelen `myReview` oturumdaki
    // kopyanın önüne geçer.
    test('sonraki fetch sunucunun kaydını öne alır', () async {
      final provider = providerWith(createdApi());
      await provider.submitReview(assignmentId: 'asg_1', rating: 3);

      final fresh = assignmentWith(
        myReview: {'id': 'rev_server', 'rating': 3, 'comment': 'Sunucudan'},
      );

      expect(provider.ownReviewFor(fresh)?.id, 'rev_server');
    });

    // Eski sunucu (alan yok) için tek sinyal reddin kodu: kullanıcı açısından
    // sonuç "yazılmış", düğme çıkmasın; içerik bilinmiyor.
    test('REVIEW_ALREADY_REVIEWED atamayı içeriksiz işaretler', () async {
      final provider = providerWith(alreadyReviewedApi());

      final sent = await provider.submitReview(
        assignmentId: 'asg_1',
        rating: 5,
      );

      expect(sent, isFalse);
      expect(provider.errorMessage, 'Bu iş için zaten değerlendirme yaptınız.');
      expect(provider.hasReviewed(assignmentWith()), isTrue);
      expect(provider.ownReviewFor(assignmentWith()), isNull);
    });

    test('REVIEW_WORK_NOT_COMPLETED atamayı işaretlemez', () async {
      final provider = providerWith(workNotCompletedApi());

      final sent = await provider.submitReview(
        assignmentId: 'asg_1',
        rating: 5,
      );

      expect(sent, isFalse);
      expect(provider.hasReviewed(assignmentWith()), isFalse);
      expect(
        provider.errorMessage,
        'İş tamamlanmadan değerlendirme yapılamaz.',
      );
    });

    // Ayrımın kategoriden gelemeyeceğini ölçen test: iki reddin durum kodu da
    // kategorisi de birebir aynı, yalnızca `errorCode` farklı.
    test('iki red aynı kategoriyle gelip farklı sonuçlanıyor', () async {
      final reviewed = providerWith(alreadyReviewedApi());
      final notCompleted = providerWith(workNotCompletedApi());

      await reviewed.submitReview(assignmentId: 'asg_1', rating: 5);
      await notCompleted.submitReview(assignmentId: 'asg_1', rating: 5);

      expect(reviewed.hasReviewed(assignmentWith()), isTrue);
      expect(notCompleted.hasReviewed(assignmentWith()), isFalse);
    });

    for (final envelope in <String, Map<String, dynamic>>{
      'kod yokken': {'success': false, 'message': 'Olmadı'},
      'kod tanınmazken': {
        'success': false,
        'message': 'Olmadı',
        'errorCode': 'REVIEW_SOMETHING_NEW',
        'errorCategory': 'DATA_CONFLICT',
      },
    }.entries) {
      test('${envelope.key} atama işaretlenmiyor', () async {
        final provider = providerWith(
          FakeApi(
            handler: (_) =>
                FakeApiResponse(statusCode: 409, body: envelope.value),
          ),
        );

        await provider.submitReview(assignmentId: 'asg_1', rating: 5);

        expect(provider.hasReviewed(assignmentWith()), isFalse);
      });
    }

    // Disk önbelleği kaldırıldı: gönderim hiçbir anahtar yazmıyor.
    test('gönderim diske yazmaz', () async {
      final provider = providerWith(createdApi());
      await provider.submitReview(assignmentId: 'asg_1', rating: 4);

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getKeys(), isEmpty);
    });

    test('clear oturum belleğini siler', () async {
      final provider = providerWith(createdApi());
      await provider.submitReview(assignmentId: 'asg_1', rating: 5);

      provider.clear();

      expect(provider.hasReviewed(assignmentWith()), isFalse);
      expect(provider.ownReviewFor(assignmentWith()), isNull);
      expect(provider.errorMessage, isNull);
    });
  });

  group('ReviewProvider.purgeLegacyCache', () {
    // Önceki sürümlerin kimliksiz ve kullanıcı anahtarlı kayıtları bir kez
    // siliniyor; başka anahtarlara dokunulmuyor.
    test('eski önbellek anahtarlarını siler, diğerlerine dokunmaz', () async {
      SharedPreferences.setMockInitialValues({
        'reviewed_assignments': ['asg_legacy'],
        'reviewed_assignments:me': ['asg_9'],
        'reviewed_assignment_details:me': '{"asg_9":{"id":"rev_9"}}',
        'reviewed_assignment_details': '{}',
        'seen_onboarding': true,
      });

      await ReviewProvider.purgeLegacyCache();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'seen_onboarding'});
    });

    test('silinecek bir şey yoksa sessizce biter', () async {
      await ReviewProvider.purgeLegacyCache();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });
  });
}
