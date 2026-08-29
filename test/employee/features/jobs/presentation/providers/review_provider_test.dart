import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_api.dart';

FakeApi createdApi() => FakeApi(
  handler: (_) => const FakeApiResponse(
    statusCode: 201,
    body: {
      'success': true,
      'data': {
        'id': 'rev_1',
        'rating': 5,
        'author': {'id': 'u1', 'firstName': 'Ada', 'lastName': 'Kaya'},
      },
    },
  ),
);

FakeApi conflictApi() => FakeApi(
  handler: (_) => const FakeApiResponse(
    statusCode: 409,
    body: {'success': false, 'message': 'Bu iş zaten değerlendirilmiş'},
  ),
);

ReviewProvider providerWith(FakeApi api) =>
    ReviewProvider(service: ReviewService.withClient(api.client));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ReviewProvider.submitReview', () {
    test('başarılı gönderim atamayı işaretler', () async {
      final provider = providerWith(createdApi());

      final sent = await provider.submitReview(
        assignmentId: 'asg_1',
        rating: 5,
      );

      expect(sent, isTrue);
      expect(provider.hasReviewed('asg_1'), isTrue);
      expect(provider.errorMessage, isNull);
    });

    // Sunucuda "değerlendirdim mi" diye sorulacak uç yok; 409 tek kaynak.
    // Kullanıcı açısından sonuç "yazıldı" olduğu için atama yine işaretleniyor.
    test('409 da atamayı işaretler', () async {
      final provider = providerWith(conflictApi());

      final sent = await provider.submitReview(
        assignmentId: 'asg_1',
        rating: 5,
      );

      expect(sent, isFalse);
      expect(provider.hasReviewed('asg_1'), isTrue);
      expect(provider.errorMessage, isNotNull);
    });

    test('işaret cihazda saklanır', () async {
      final provider = providerWith(createdApi());
      await provider.submitReview(assignmentId: 'asg_1', rating: 4);

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getStringList('reviewed_assignments'), ['asg_1']);
    });

    test('atama kimliği yoksa değerlendirilmiş sayılmaz', () {
      final provider = providerWith(createdApi());

      expect(provider.hasReviewed(null), isFalse);
    });
  });

  group('ReviewProvider kapsülleme', () {
    test('kayıtlı işaretler açılışta geri yüklenir', () async {
      SharedPreferences.setMockInitialValues({
        'reviewed_assignments': ['asg_9'],
      });

      final provider = providerWith(createdApi());
      // Kurucudaki okuma asenkron; bir tur bekleniyor.
      await Future<void>.delayed(Duration.zero);

      expect(provider.hasReviewed('asg_9'), isTrue);
    });

    test('clear çıkışta işaretleri hem bellekten hem diskten siler', () async {
      final provider = providerWith(createdApi());
      await provider.submitReview(assignmentId: 'asg_1', rating: 5);

      await provider.clear();
      final prefs = await SharedPreferences.getInstance();

      expect(provider.hasReviewed('asg_1'), isFalse);
      expect(prefs.getStringList('reviewed_assignments'), isNull);
    });

    test('reviewedAssignmentIds dışarıdan değiştirilemez', () async {
      final provider = providerWith(createdApi());
      await provider.submitReview(assignmentId: 'asg_1', rating: 5);

      expect(
        () => provider.reviewedAssignmentIds.add('asg_2'),
        throwsUnsupportedError,
      );
    });
  });
}
