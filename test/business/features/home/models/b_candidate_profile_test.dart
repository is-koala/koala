import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/b_candidate_profile.dart';

void main() {
  const base = {
    'id': 'worker-1',
    'firstName': 'Ayşe',
    'lastName': 'Yılmaz',
    'jobTitle': 'Barista',
    'cityName': 'Ankara',
    'districtName': 'Çankaya',
  };

  group('BCandidateProfile', () {
    test('profil ve koala-backend#282 özet alanları aynı yanıttan okunur', () {
      final candidate = BCandidateProfile.fromJson(const {
        ...base,
        'completedJobCount': 7,
        'averageRating': 4.5,
        'reviewCount': 12,
        'badges': [
          {'code': 'GEZGIN_GOLD', 'tier': 'GOLD', 'name': 'Gezgin'},
        ],
      });

      expect(candidate.profile.fullName, 'Ayşe Yılmaz');
      expect(candidate.profile.locationLabel, 'Çankaya/Ankara');
      expect(candidate.completedJobCount, 7);
      expect(candidate.ratingSummary?.userId, 'worker-1');
      expect(candidate.ratingSummary?.averageRating, 4.5);
      expect(candidate.ratingSummary?.reviewCount, 12);
      expect(candidate.ratingSummary?.hasRating, isTrue);
      expect(candidate.badges?.single.code, 'GEZGIN_GOLD');
    });

    // BigDecimal JSON'da dize olarak da gelebiliyor.
    test('ortalama puan dize gelince de okunur', () {
      final candidate = BCandidateProfile.fromJson(const {
        ...base,
        'averageRating': '3.80',
        'reviewCount': 5,
      });

      expect(candidate.ratingSummary?.averageRating, 3.8);
    });

    test('hiç değerlendirilmemiş adayda puan yok sayılır', () {
      final candidate = BCandidateProfile.fromJson(const {
        ...base,
        'averageRating': 0,
        'reviewCount': 0,
        'badges': [],
      });

      expect(candidate.ratingSummary?.hasRating, isFalse);
      expect(candidate.badges, isEmpty);
    });

    // Eski sunucu bu alanları göndermiyor: "yok" ile "gönderilmedi" ayrı.
    test('alanlar yokken null kalır', () {
      final candidate = BCandidateProfile.fromJson(const {...base});

      expect(candidate.profile.id, 'worker-1');
      expect(candidate.completedJobCount, isNull);
      expect(candidate.ratingSummary, isNull);
      expect(candidate.badges, isNull);
    });
  });
}
