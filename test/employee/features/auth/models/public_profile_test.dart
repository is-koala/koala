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
}
