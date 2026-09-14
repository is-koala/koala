import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/services/b_candidate_profile_service.dart';

import '../../../../support/fake_api.dart';

void main() {
  group('BCandidateProfileService', () {
    test('profili ve aynı yanıttaki özet alanları tek istekle okur', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'worker-1',
              'firstName': 'Ayşe',
              'lastName': 'Yılmaz',
              'completedJobCount': 4,
              'averageRating': 4.2,
              'reviewCount': 5,
              'badges': [
                {'code': 'GEZGIN_GOLD', 'tier': 'GOLD', 'name': 'Gezgin'},
              ],
            },
          },
        ),
      );

      final candidate = await BCandidateProfileService.withClient(
        api.client,
      ).fetchProfile('worker-1');

      expect(api.requests.single.path, '/users/worker-1');
      expect(candidate.profile.fullName, 'Ayşe Yılmaz');
      expect(candidate.completedJobCount, 4);
      expect(candidate.ratingSummary?.reviewCount, 5);
      expect(candidate.badges?.single.code, 'GEZGIN_GOLD');
    });

    test('rozetleri düz liste olarak okur', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {
                'code': 'IDENTITY',
                'tier': 'NONE',
                'name': 'Kimliği Doğrulandı',
              },
            ],
          },
        ),
      );

      final badges = await BCandidateProfileService.withClient(
        api.client,
      ).fetchBadges('worker-1');

      expect(api.requests.single.path, '/users/worker-1/badges');
      expect(badges.single.name, 'Kimliği Doğrulandı');
    });

    test('rozeti olmayan kullanıcıda boş liste döner', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': []},
        ),
      );

      final badges = await BCandidateProfileService.withClient(
        api.client,
      ).fetchBadges('worker-1');

      expect(badges, isEmpty);
    });
  });
}
