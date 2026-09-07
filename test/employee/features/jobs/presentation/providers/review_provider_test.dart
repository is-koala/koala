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

/// Sunucunun `ReviewManager.leaveReview` içinden dönen iki reddi de aynı
/// `ConflictException`, yani aynı durum kodu **ve** aynı kategori. Tek fark
/// `errorCode`: `KoalaException` onu mesaj anahtarından türetiyor.
FakeApi conflictApi({required String errorCode, required String message}) =>
    FakeApi(
      handler: (_) => FakeApiResponse(
        statusCode: 409,
        body: {
          'success': false,
          'message': message,
          'errorCode': errorCode,
          'errorCategory': 'DATA_CONFLICT',
        },
      ),
    );

FakeApi alreadyReviewedApi() => conflictApi(
  errorCode: 'REVIEW_ALREADY_REVIEWED',
  message: 'Bu iş zaten değerlendirilmiş',
);

FakeApi workNotCompletedApi() => conflictApi(
  errorCode: 'REVIEW_WORK_NOT_COMPLETED',
  message: 'İş henüz tamamlanmadı',
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

    // Sunucuda "değerlendirdim mi" diye sorulacak uç yok; reddin kendisi tek
    // kaynak. Kullanıcı açısından sonuç "yazıldı" olduğu için işaretleniyor.
    test('REVIEW_ALREADY_REVIEWED atamayı işaretler', () async {
      final provider = providerWith(alreadyReviewedApi());

      final sent = await provider.submitReview(
        assignmentId: 'asg_1',
        rating: 5,
      );

      expect(sent, isFalse);
      expect(provider.hasReviewed('asg_1'), isTrue);
      expect(provider.errorMessage, isNotNull);
    });

    // Asıl kusur buydu: iş tamamlanmadığı için reddedilen kullanıcı, atamayı
    // "değerlendirilmiş" olarak diske yazdığı için iş tamamlandıktan sonra da
    // bir daha hiç değerlendiremiyordu.
    test('REVIEW_WORK_NOT_COMPLETED atamayı işaretlemez', () async {
      final provider = providerWith(workNotCompletedApi());

      final sent = await provider.submitReview(
        assignmentId: 'asg_1',
        rating: 5,
      );

      expect(sent, isFalse);
      expect(provider.hasReviewed('asg_1'), isFalse);
      expect(provider.errorMessage, 'İş henüz tamamlanmadı');
    });

    // Ayrımın kategoriden gelemeyeceğini ölçen test: iki reddin durum kodu da
    // kategorisi de birebir aynı, yalnızca `errorCode` farklı. Kod yerine
    // `type` ya da `statusCode` okunsaydı ikisi de aynı tarafa düşerdi.
    test('iki red aynı kategoriyle gelip farklı sonuçlanıyor', () async {
      final reviewed = providerWith(alreadyReviewedApi());
      final notCompleted = providerWith(workNotCompletedApi());

      await reviewed.submitReview(assignmentId: 'asg_1', rating: 5);
      await notCompleted.submitReview(assignmentId: 'asg_1', rating: 5);

      expect(reviewed.hasReviewed('asg_1'), isTrue);
      expect(notCompleted.hasReviewed('asg_1'), isFalse);
    });

    // Kod hiç gelmezse ya da tanınmazsa işaretlenmiyor: fazladan bir buton
    // göstermek, atamayı kalıcı olarak değerlendirilemez yapmaktan iyi.
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

        expect(provider.hasReviewed('asg_1'), isFalse);
      });
    }

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
