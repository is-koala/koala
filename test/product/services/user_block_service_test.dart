import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/user_block.dart';
import 'package:koala/product/services/user_block_service.dart';

import '../../support/fake_api.dart';

/// `SuccessResult` dönen uçların yanıtı: engelleme ve engel kaldırma.
const _successResult = FakeApiResponse(
  statusCode: 200,
  body: {'success': true, 'data': null},
);

/// `GET /users/me/blocks` yanıtı. Sayfalı değil, düz liste.
const _blockList = FakeApiResponse(
  statusCode: 200,
  body: {
    'success': true,
    'data': [
      {
        'id': 'blk_1',
        'blocked': {
          'id': 'u9',
          'firstName': 'Ayşe',
          'lastName': 'Yılmaz',
          'username': 'ayseyilmaz',
          'profilePictureUrl': 'https://cdn.local/u9.png',
        },
        'reason': 'Israrla mesaj attı',
        'createdAt': '2026-02-15T09:00:00',
      },
    ],
  },
);

void main() {
  group('UserBlockService.block', () {
    test('engelleme /users/me/blocks/{userId} yoluna POST edilir', () async {
      final api = FakeApi(handler: (_) => _successResult);

      await UserBlockService.withClient(api.client).block('u9');

      expect(api.requests.single.path, '/users/me/blocks/u9');
      expect(api.requests.single.method, 'POST');
    });

    test('gerekçe verilmese de gövde gönderilir', () async {
      final api = FakeApi(handler: (_) => _successResult);

      await UserBlockService.withClient(api.client).block('u9');

      // Sunucu `@RequestBody @Valid` ile gövdeyi zorunlu tutuyor
      // (`required = false` değil): gövdesiz istek `400` alırdı.
      expect(api.requests.single.data, isA<Map<String, dynamic>>());
      expect(api.requests.single.data, isEmpty);
    });

    test('gerekçe verilirse gövdeye konur', () async {
      final api = FakeApi(handler: (_) => _successResult);

      await UserBlockService.withClient(
        api.client,
      ).block('u9', reason: 'Israrla mesaj attı');

      expect(api.requests.single.data, {'reason': 'Israrla mesaj attı'});
    });

    test('boşluktan ibaret gerekçe gövdeye konmaz', () async {
      final api = FakeApi(handler: (_) => _successResult);

      await UserBlockService.withClient(api.client).block('u9', reason: '   ');

      expect(api.requests.single.data, isEmpty);
    });

    test('gerekçe 512 karakterle sınırlanıyor', () async {
      final api = FakeApi(handler: (_) => _successResult);

      await UserBlockService.withClient(
        api.client,
      ).block('u9', reason: 'a' * 600);

      final body = api.requests.single.data as Map<String, dynamic>;
      expect((body['reason'] as String).length, UserBlockService.reasonLimit);
    });
  });

  group('UserBlockService.unblock', () {
    test('engel kaldırma aynı yola DELETE edilir', () async {
      final api = FakeApi(handler: (_) => _successResult);

      await UserBlockService.withClient(api.client).unblock('u9');

      expect(api.requests.single.path, '/users/me/blocks/u9');
      expect(api.requests.single.method, 'DELETE');
    });
  });

  group('UserBlockService.fetchMyBlocks', () {
    test('liste /users/me/blocks yolundan çekiliyor', () async {
      final api = FakeApi(handler: (_) => _blockList);

      await UserBlockService.withClient(api.client).fetchMyBlocks();

      expect(api.requests.single.path, '/users/me/blocks');
      expect(api.requests.single.method, 'GET');
      // Sayfalı değil: sayfa parametresi gönderilmiyor.
      expect(api.requests.single.queryParameters, isEmpty);
    });

    test('düz liste modele çevriliyor', () async {
      final api = FakeApi(handler: (_) => _blockList);

      final blocks = await UserBlockService.withClient(
        api.client,
      ).fetchMyBlocks();

      expect(blocks, hasLength(1));

      final block = blocks.single;
      expect(block.id, 'blk_1');
      expect(block.reason, 'Israrla mesaj attı');
      expect(block.createdAt, DateTime.parse('2026-02-15T09:00:00'));
      expect(block.blocked.id, 'u9');
      expect(block.blocked.displayName, 'Ayşe Yılmaz');
      expect(block.blocked.profilePictureUrl, 'https://cdn.local/u9.png');
    });

    test('boş liste boş sonuç veriyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': <Object?>[]},
        ),
      );

      final blocks = await UserBlockService.withClient(
        api.client,
      ).fetchMyBlocks();

      expect(blocks, isEmpty);
    });
  });

  group('BlockedUser', () {
    test('adı olmayan kullanıcı kullanıcı adıyla anılıyor', () {
      final block = UserBlock.fromJson(const {
        'id': 'blk_2',
        'blocked': {'id': 'u4', 'username': 'kaan'},
      });

      expect(block.blocked.displayName, '@kaan');
    });

    test('hiçbir adı olmayan kullanıcı için yer tutucu var', () {
      final block = UserBlock.fromJson(const {
        'id': 'blk_3',
        'blocked': {'id': 'u5'},
      });

      expect(block.blocked.displayName, 'Kullanıcı');
    });
  });
}
