import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/education.dart';
import 'package:koala/employee/features/auth/models/experience.dart';
import 'package:koala/employee/features/auth/models/user_badge.dart';
import 'package:koala/product/constants/app_assets.dart';

void main() {
  group('Experience', () {
    test('JSON modele çevrilir', () {
      final experience = Experience.fromJson({
        'id': 'exp-1',
        'title': 'Kıdemli Fotoğrafçı',
        'companyName': 'Studio Kreatif',
        'employmentType': 'PART_TIME',
        'cityName': 'İstanbul',
        'startDate': '2023-01-01',
        'description': 'Kurumsal etkinlik çekimleri.',
      });

      expect(experience.title, 'Kıdemli Fotoğrafçı');
      expect(experience.employmentType, EmploymentType.partTime);
      expect(experience.subtitle, 'Studio Kreatif · İstanbul');
      expect(experience.durationLabel, 'Ocak 2023 - Halen');
    });

    test('şirket yoksa alt satır yalnız şehri taşır', () {
      final experience = Experience.fromJson({
        'id': 'exp-2',
        'title': 'Serbest',
        'cityName': 'Ankara',
      });

      expect(experience.subtitle, 'Ankara');
    });

    test('tanınmayan çalışma biçimi varsayılana düşer', () {
      final experience = Experience.fromJson({
        'id': 'exp-3',
        'title': 'X',
        'employmentType': 'UZAYLI',
      });

      expect(experience.employmentType, EmploymentType.fullTime);
    });
  });

  group('Education', () {
    test('JSON modele çevrilir', () {
      final education = Education.fromJson({
        'id': 'edu-1',
        'universityName': 'Boğaziçi Üniversitesi',
        'facultyName': 'Mühendislik',
        'departmentName': 'Bilgisayar Mühendisliği',
        'type': 'GRADUATE',
        'gpa': 3.4,
      });

      expect(education.type, GradeType.graduate);
      expect(education.gpa, 3.4);
      expect(education.subtitle, 'Bilgisayar Mühendisliği · Mühendislik');
    });

    test('gpa sıfırsa girilmemiş sayılır', () {
      final education = Education.fromJson({'id': 'edu-2', 'gpa': 0});

      expect(education.gpa, isNull);
    });
  });

  group('UserBadge', () {
    test('Gezgin altın yerel görsele eşlenir', () {
      final badge = UserBadge.fromJson({
        'code': 'GEZGIN_GOLD',
        'name': 'Gezgin',
        'family': 'GEZGIN',
        'tier': 'GOLD',
        'earnedAt': '2026-08-01T10:00:00Z',
      });

      expect(badge.localAsset, AppAssets.badgeGold);
      expect(badge.earnedAt, isNotNull);
    });

    test('başka aile yerel görsele eşlenmez, iconUrl kalır', () {
      final badge = UserBadge.fromJson({
        'code': 'RATING_GOLD',
        'name': 'Yüksek Puan',
        'family': 'RATING',
        'tier': 'GOLD',
        'iconUrl': 'https://cdn/badge.png',
      });

      expect(badge.localAsset, isNull);
      expect(badge.iconUrl, 'https://cdn/badge.png');
    });

    test('tanınmayan aile ve kademe varsayılana düşer', () {
      final badge = UserBadge.fromJson({'code': 'X', 'name': 'X'});

      expect(badge.family, BadgeFamily.other);
      expect(badge.tier, BadgeTier.none);
      expect(badge.localAsset, isNull);
    });
  });

  group('CurrentUser yeni alanlar', () {
    test('liste alanları ayrıştırılır ve tur atlatır', () {
      final json = {
        'id': 'user-1',
        'firstName': 'Yakup',
        'lastName': 'Kahraman',
        'email': 'a@b.com',
        'jobTitle': 'Fotoğrafçı',
        'isEmployer': false,
        'maskedIban': 'TR** **** 1234',
        'cvUrl': 'https://cdn/cv.pdf',
        'experiences': [
          {'id': 'exp-1', 'title': 'Fotoğrafçı', 'startDate': '2023-01-01'},
        ],
        'educations': [
          {'id': 'edu-1', 'universityName': 'Boğaziçi'},
        ],
        'badges': [
          {'code': 'GEZGIN_GOLD', 'name': 'Gezgin', 'family': 'GEZGIN'},
        ],
      };

      final user = CurrentUser.fromJson(json);

      expect(user.jobTitle, 'Fotoğrafçı');
      expect(user.maskedIban, 'TR** **** 1234');
      expect(user.cvUrl, 'https://cdn/cv.pdf');
      expect(user.experiences.single.title, 'Fotoğrafçı');
      expect(user.educations.single.universityName, 'Boğaziçi');
      expect(user.badges.single.code, 'GEZGIN_GOLD');
      expect(CurrentUser.fromJson(user.toJson()).toJson(), user.toJson());
    });

    test('liste alanları hiç gelmezse boş kalır, çökmez', () {
      final user = CurrentUser.fromJson({
        'isEmployer': false,
        'id': 'user-1',
        'firstName': 'Yakup',
        'lastName': 'Kahraman',
        'email': 'a@b.com',
      });

      expect(user.experiences, isEmpty);
      expect(user.educations, isEmpty);
      expect(user.badges, isEmpty);
      expect(user.jobTitle, isNull);
    });

    // Backend `experiences` alanını düz `String`'den listeye çevirdi; eski
    // biçimde bir yanıt gelirse uygulama çökmemeli.
    test('experiences beklenmedik tipte gelirse boş liste olur', () {
      final user = CurrentUser.fromJson({
        'id': 'user-1',
        'firstName': 'Yakup',
        'lastName': 'Kahraman',
        'email': 'a@b.com',
        'experiences': 'eski düz metin',
        'isEmployer': false,
      });

      expect(user.experiences, isEmpty);
    });
  });
}
