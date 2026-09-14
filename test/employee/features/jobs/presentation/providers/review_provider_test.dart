import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/fake_api.dart';

FakeApi createdApi() => FakeApi(
  handler: (request) => FakeApiResponse(
    statusCode: 201,
    body: {
      'success': true,
      'data': {
        'id': 'rev_1',
        'rating': (request.data as Map<String, dynamic>)['rating'],
        'comment': ?(request.data as Map<String, dynamic>)['comment'],
        'author': {'id': 'u1', 'firstName': 'Ada', 'lastName': 'Kaya'},
      },
    },
  ),
);

Map<String, Object?> reviewJson({
  required String id,
  required String authorId,
  required int rating,
  String? comment,
  String? createdAt,
}) => {
  'id': id,
  'rating': rating,
  'comment': ?comment,
  'author': {'id': authorId, 'firstName': 'Ada', 'lastName': 'Kaya'},
  'createdAt': ?createdAt,
};

/// `GET /users/{id}/reviews` için sayfalı yanıt; diğer istekler 201.
FakeApi reviewsAboutApi(
  List<Map<String, Object?>> reviews, {
  List<RequestOptions>? seen,
}) => FakeApi(
  handler: (request) {
    seen?.add(request);
    if (request.method == 'GET') {
      return FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {'content': reviews, 'last': true},
        },
      );
    }
    return const FakeApiResponse(
      statusCode: 409,
      body: {
        'success': false,
        'message': 'Bu iş için zaten değerlendirme yaptınız.',
        'errorCode': 'REVIEW_ALREADY_REVIEWED',
        'errorCategory': 'DATA_CONFLICT',
      },
    );
  },
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

    // İşveren kartı "Değerlendirdiniz: ★4 · yorum" satırını buradan çiziyor;
    // sunucunun yanıtı olduğu gibi saklanıyor, ikinci istek atılmıyor.
    test('başarılı gönderimde kendi kaydı içeriğiyle tutulur', () async {
      final provider = providerWith(createdApi());

      await provider.submitReview(
        assignmentId: 'asg_1',
        rating: 4,
        comment: 'Dakik ve titiz.',
      );

      final own = provider.ownReviewFor('asg_1');
      expect(own, isNotNull);
      expect(own!.rating, 4);
      expect(own.summaryLabel, '★4 · "Dakik ve titiz."');
      expect(provider.ownReviewFor('asg_2'), isNull);
    });

    test('yorumsuz kaydın özeti yalnızca yıldız', () async {
      final provider = providerWith(createdApi());

      await provider.submitReview(assignmentId: 'asg_1', rating: 5);

      expect(provider.ownReviewFor('asg_1')!.summaryLabel, '★5');
    });

    // 409 ile işaretlenen atamanın içeriği bilinmiyor: `null` "değerlendirilmedi"
    // demek değil, `hasReviewed` ondan ayrı.
    test('409 ile işaretlenen atamanın içeriği yok', () async {
      final provider = providerWith(alreadyReviewedApi());

      await provider.submitReview(assignmentId: 'asg_1', rating: 5);

      expect(provider.hasReviewed('asg_1'), isTrue);
      expect(provider.ownReviewFor('asg_1'), isNull);
    });
  });

  group('ReviewProvider.loadOwnReview', () {
    // Sunucu "hangi atamaya" demiyor; yazarı biz olan ve tamamlanmadan sonra
    // yazılmış en eski kayıt seçiliyor, başkasının kaydı elenmiş oluyor.
    test('işaretli atamanın kaydını yazara ve tarihe göre bulur', () async {
      final provider = providerWith(
        reviewsAboutApi([
          reviewJson(
            id: 'rev_other',
            authorId: 'u_other',
            rating: 1,
            createdAt: '2026-09-11T10:00:00Z',
          ),
          reviewJson(
            id: 'rev_old',
            authorId: 'me',
            rating: 2,
            createdAt: '2026-09-01T10:00:00Z',
          ),
          reviewJson(
            id: 'rev_mine',
            authorId: 'me',
            rating: 4,
            comment: 'Güzel iş',
            createdAt: '2026-09-11T09:00:00Z',
          ),
        ]),
      );
      await provider.submitReview(assignmentId: 'asg_1', rating: 5);

      await provider.loadOwnReview(
        assignmentId: 'asg_1',
        subjectUserId: 'worker-1',
        authorUserId: 'me',
        completedAt: DateTime.parse('2026-09-10T17:00:00Z'),
      );

      expect(provider.ownReviewFor('asg_1')?.id, 'rev_mine');
    });

    // Arama değerlendirilmişliğe karar vermez: işaretsiz atamada hiç
    // gidilmiyor, aksi hâlde aynı kişiyle ikinci iş yanlış işaretlenirdi.
    test('işaretsiz atamada sunucuya gitmez', () async {
      final seen = <RequestOptions>[];
      final provider = providerWith(
        reviewsAboutApi([
          reviewJson(id: 'rev_mine', authorId: 'me', rating: 4),
        ], seen: seen),
      );

      await provider.loadOwnReview(
        assignmentId: 'asg_1',
        subjectUserId: 'worker-1',
        authorUserId: 'me',
      );

      expect(seen, isEmpty);
      expect(provider.hasReviewed('asg_1'), isFalse);
      expect(provider.ownReviewFor('asg_1'), isNull);
    });

    test('içeriği bilinen atama için tekrar sormaz', () async {
      final gets = <RequestOptions>[];
      final provider = providerWith(
        FakeApi(
          handler: (request) {
            if (request.method == 'GET') gets.add(request);
            return const FakeApiResponse(
              statusCode: 201,
              body: {
                'success': true,
                'data': {'id': 'rev_1', 'rating': 3},
              },
            );
          },
        ),
      );
      await provider.submitReview(assignmentId: 'asg_1', rating: 3);

      await provider.loadOwnReview(
        assignmentId: 'asg_1',
        subjectUserId: 'worker-1',
        authorUserId: 'me',
      );

      expect(gets, isEmpty);
      expect(provider.ownReviewFor('asg_1')?.id, 'rev_1');
    });

    test('kendi kaydı yoksa satır içeriksiz kalır, hata yükselmez', () async {
      final provider = providerWith(
        FakeApi(
          handler: (request) => request.method == 'GET'
              ? const FakeApiResponse(
                  statusCode: 500,
                  body: {'success': false, 'message': 'Olmadı'},
                )
              : const FakeApiResponse(
                  statusCode: 409,
                  body: {
                    'success': false,
                    'message': 'Zaten var',
                    'errorCode': 'REVIEW_ALREADY_REVIEWED',
                    'errorCategory': 'DATA_CONFLICT',
                  },
                ),
        ),
      );
      await provider.submitReview(assignmentId: 'asg_1', rating: 5);

      await provider.loadOwnReview(
        assignmentId: 'asg_1',
        subjectUserId: 'worker-1',
        authorUserId: 'me',
      );

      expect(provider.hasReviewed('asg_1'), isTrue);
      expect(provider.ownReviewFor('asg_1'), isNull);
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

    test('kayıtlı içerik açılışta geri yüklenir', () async {
      SharedPreferences.setMockInitialValues({
        'reviewed_assignments': ['asg_9'],
        'reviewed_assignment_details':
            '{"asg_9":{"id":"rev_9","rating":4,"comment":"İyi"}}',
      });

      final provider = providerWith(createdApi());
      await Future<void>.delayed(Duration.zero);

      expect(provider.ownReviewFor('asg_9')?.summaryLabel, '★4 · "İyi"');
    });

    // Bozuk içerik kaydı kimlikleri götürmez: rozet kalır, içerik düşer.
    test('bozuk içerik kaydı işaretleri bozmaz', () async {
      SharedPreferences.setMockInitialValues({
        'reviewed_assignments': ['asg_9'],
        'reviewed_assignment_details': '{bozuk',
      });

      final provider = providerWith(createdApi());
      await Future<void>.delayed(Duration.zero);

      expect(provider.hasReviewed('asg_9'), isTrue);
      expect(provider.ownReviewFor('asg_9'), isNull);
    });

    test('clear çıkışta işaretleri hem bellekten hem diskten siler', () async {
      final provider = providerWith(createdApi());
      await provider.submitReview(assignmentId: 'asg_1', rating: 5);

      await provider.clear();
      final prefs = await SharedPreferences.getInstance();

      expect(provider.hasReviewed('asg_1'), isFalse);
      expect(provider.ownReviewFor('asg_1'), isNull);
      expect(prefs.getStringList('reviewed_assignments'), isNull);
      expect(prefs.getString('reviewed_assignment_details'), isNull);
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
