import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/public_profile.dart';

void main() {
  test('yanıt modele çevriliyor', () {
    final profile = PublicProfile.fromJson(const {
      'id': 'user_1',
      'firstName': 'Ayşe',
      'lastName': 'Yılmaz',
      'username': 'ayse',
      'profilePictureUrl': 'https://cdn.local/a.png',
      'jobTitle': 'Barista',
      'about': 'Üç yıldır kahve yapıyorum.',
      'cityName': 'Ankara',
      'districtName': 'Çankaya',
      'cvUrl': 'https://api.local/storage/cv.pdf',
    });

    expect(profile.fullName, 'Ayşe Yılmaz');
    expect(profile.locationLabel, 'Çankaya/Ankara');
    expect(profile.hasCv, isTrue);
  });

  test('konumun tek parçası varsa o yazılıyor', () {
    final profile = PublicProfile.fromJson(const {
      'id': 'u',
      'firstName': 'A',
      'lastName': 'B',
      'cityName': 'Ankara',
    });

    expect(profile.locationLabel, 'Ankara');
  });

  test('konum hiç gelmezse null', () {
    final profile = PublicProfile.fromJson(const {
      'id': 'u',
      'firstName': 'A',
      'lastName': 'B',
    });

    // Sunucu tam adres döndürmüyor; il/ilçe de boş olabiliyor.
    expect(profile.locationLabel, isNull);
  });

  test('cvUrl gelmezse özgeçmiş yok sayılıyor', () {
    final profile = PublicProfile.fromJson(const {
      'id': 'u',
      'firstName': 'A',
      'lastName': 'B',
    });

    // Adres yalnızca yetkili görene doluyor; boş gelmesi hata değil.
    expect(profile.hasCv, isFalse);
  });

  // koala-backend#282: özet profil yanıtında; çalışan tarafındaki herkese
  // açık profil sayfası puan için ayrı uç çağırmıyor.
  group('puan özeti', () {
    test('sayı ve dize olarak gelen ortalama okunuyor', () {
      for (final average in <Object>[4.5, '4.50']) {
        final profile = PublicProfile.fromJson({
          'id': 'u',
          'firstName': 'A',
          'lastName': 'B',
          'reviewCount': 12,
          'averageRating': average,
        });

        expect(profile.reviewCount, 12, reason: '$average');
        expect(profile.averageRating, 4.5, reason: '$average');
      }
    });

    test('alanlar yoksa null: eski sunucu "değerlendirme yok" demiyor', () {
      final profile = PublicProfile.fromJson(const {
        'id': 'u',
        'firstName': 'A',
        'lastName': 'B',
      });

      expect(profile.reviewCount, isNull);
      expect(profile.averageRating, isNull);
    });

    test('sıfır değerlendirme null değil, sıfır', () {
      final profile = PublicProfile.fromJson(const {
        'id': 'u',
        'firstName': 'A',
        'lastName': 'B',
        'reviewCount': 0,
        'averageRating': 0,
      });

      expect(profile.reviewCount, 0);
      expect(profile.averageRating, 0);
    });
  });
}
