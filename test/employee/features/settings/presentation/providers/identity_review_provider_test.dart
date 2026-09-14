import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/settings/services/identity_document_service.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/identity_document_fixtures.dart';

void main() {
  IdentityReviewProvider providerFor(FakeApi api) => IdentityReviewProvider(
    service: IdentityDocumentService.withClient(api.client),
  );

  test('yükleme sonrası inceleme ve hasLoaded dolu', () async {
    final api = FakeApi(
      handler: (_) => identityReviewResponse(status: 'PENDING'),
    );
    final provider = providerFor(api);

    expect(provider.hasLoaded, isFalse);
    await provider.load();

    expect(provider.hasLoaded, isTrue);
    expect(provider.review?.status, IdentityReviewStatus.pending);
    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, isNull);
  });

  test('hiç inceleme yoksa review null ama hasLoaded true', () async {
    // "bilinmiyor" ile "yok" ayrı: rozet ilkinde bayrağa, ikincisinde
    // duruma göre çiziliyor.
    final api = FakeApi(handler: (_) => noIdentityReviewResponse);
    final provider = providerFor(api);

    await provider.load(silent: true);

    expect(provider.hasLoaded, isTrue);
    expect(provider.review, isNull);
    expect(
      provider.statusFor(identityVerified: false),
      IdentityStatus.unverified,
    );
  });

  test('hata eldeki kaydı korur ve mesajı taşır', () async {
    var fail = false;
    final api = FakeApi(
      handler: (_) => fail
          ? const FakeApiResponse.connectionError()
          : identityReviewResponse(status: 'REJECTED'),
    );
    final provider = providerFor(api);
    await provider.load();
    fail = true;

    await provider.load();

    expect(provider.errorMessage, isNotNull);
    expect(provider.review?.status, IdentityReviewStatus.rejected);
    expect(provider.hasLoaded, isTrue);
  });

  test('süren okuma varken ikinci load aynı yanıtı bekliyor', () async {
    // Açılışta başlayan okuma sürerken kimlik ekranı açılırsa, ekranın
    // kararı bitmemiş okumanın eski değerine değil yanıtına dayanmalı.
    final gate = Completer<void>();
    final api = FakeApi(
      handler: (_) async {
        await gate.future;
        return identityReviewResponse(status: 'PENDING');
      },
    );
    final provider = providerFor(api);

    final first = provider.load(silent: true);
    final second = provider.load(silent: true);
    await api.requestsReach(1);
    expect(api.requests, hasLength(1));

    var secondDone = false;
    unawaited(second.then((_) => secondDone = true));
    await Future<void>.delayed(Duration.zero);
    expect(secondDone, isFalse, reason: 'ikinci çağrı hemen dönmemeli');

    gate.complete();
    await Future.wait([first, second]);

    expect(secondDone, isTrue);
    expect(provider.review?.status, IdentityReviewStatus.pending);
    expect(api.requests, hasLength(1), reason: 'tek istek');
  });

  test('bitmiş okumadan sonra load yeniden soruyor', () async {
    var status = 'PENDING';
    final api = FakeApi(handler: (_) => identityReviewResponse(status: status));
    final provider = providerFor(api);
    await provider.load();
    status = 'APPROVED';

    await provider.load(silent: true);

    expect(api.requests, hasLength(2));
    expect(provider.review?.status, IdentityReviewStatus.approved);
  });

  test('silent yükleme göstergeyi açmıyor, normal yükleme açıyor', () async {
    final gate = Completer<void>();
    final api = FakeApi(
      handler: (_) async {
        await gate.future;
        return noIdentityReviewResponse;
      },
    );
    final provider = providerFor(api);

    final silent = provider.load(silent: true);
    expect(provider.isLoading, isFalse);
    gate.complete();
    await silent;

    final gate2 = Completer<void>();
    final api2 = FakeApi(
      handler: (_) async {
        await gate2.future;
        return noIdentityReviewResponse;
      },
    );
    final loud = providerFor(api2);
    final loading = loud.load();
    expect(loud.isLoading, isTrue);
    gate2.complete();
    await loading;
    expect(loud.isLoading, isFalse);
  });

  test('apply gönderim yanıtını istek atmadan yerine koyuyor', () {
    final api = FakeApi(handler: (_) => noIdentityReviewResponse);
    final provider = providerFor(api);
    var notified = 0;
    provider.addListener(() => notified++);

    provider.apply(
      const IdentityReview(id: 'r', status: IdentityReviewStatus.pending),
    );

    expect(provider.review?.isPending, isTrue);
    expect(provider.hasLoaded, isTrue);
    expect(notified, 1);
    expect(api.requests, isEmpty);
  });

  test('clear sonrası geç gelen yanıt yeni oturuma yazmıyor', () async {
    final gate = Completer<void>();
    final api = FakeApi(
      handler: (_) async {
        await gate.future;
        return identityReviewResponse(status: 'REJECTED');
      },
    );
    final provider = providerFor(api);

    final pending = provider.load(silent: true);
    provider.clear();
    gate.complete();
    await pending;

    expect(provider.review, isNull);
    expect(provider.hasLoaded, isFalse);
    expect(
      provider.statusFor(identityVerified: false),
      IdentityStatus.unverified,
    );
  });

  test('statusFor bayrağı incelemenin önüne koyuyor', () async {
    final api = FakeApi(
      handler: (_) => identityReviewResponse(status: 'REJECTED'),
    );
    final provider = providerFor(api);
    await provider.load();

    expect(provider.statusFor(identityVerified: true), IdentityStatus.verified);
    expect(
      provider.statusFor(identityVerified: false),
      IdentityStatus.rejected,
    );
  });
}
