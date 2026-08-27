import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';

import '../../../../support/fixtures.dart';

void main() {
  group('Job serileştirme', () {
    test('toJson → fromJson turu alanları korur', () {
      final job = buildJob(
        id: 'job_42',
        title: 'Deneyimli Barista',
        price: 15000,
        type: JobType.recurring,
        category: JobCategorySeeds.barista,
        description: 'Latte art yapabilen barista aranıyor.',
      );

      final restored = Job.fromJson(job.toJson());

      expect(restored.id, job.id);
      expect(restored.title, job.title);
      expect(restored.subtitle, job.subtitle);
      expect(restored.price, job.price);
      expect(restored.type, job.type);
      expect(restored.category, job.category);
      expect(restored.latitude, job.latitude);
      expect(restored.longitude, job.longitude);
      expect(restored.company, job.company);
      expect(restored.description, job.description);
      expect(restored.address, job.address);
    });

    test('tarihler ISO 8601 üzerinden turu atlatır', () {
      final job = Job(
        id: 'job_1',
        latitude: 39.9208,
        longitude: 32.8541,
        type: JobType.oneTime,
        category: JobCategorySeeds.photography,
        title: 'Mekan Fotoğrafçısı',
        subtitle: 'Cafe fotoğrafları çekilecek.',
        price: 2000,
        startDateTime: DateTime(2026, 2, 15, 10),
        endDateTime: DateTime(2026, 2, 15, 16, 30),
      );

      final restored = Job.fromJson(job.toJson());

      expect(restored.startDateTime, DateTime(2026, 2, 15, 10));
      expect(restored.endDateTime, DateTime(2026, 2, 15, 16, 30));
    });

    test('opsiyonel alanlar yokken null kalır', () {
      final json = {
        'id': 'job_1',
        'latitude': 39.9,
        'longitude': 32.8,
        'type': 'oneTime',
        'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
        'title': 'Garson',
        'subtitle': 'Alt başlık',
        'price': 500,
      };

      final job = Job.fromJson(json);

      expect(job.imageUrl, isNull);
      expect(job.companyDetails, isNull);
      expect(job.startDateTime, isNull);
      expect(job.minAge, isNull);
      expect(job.insuranceRequired, isNull);
    });

    test('int gelen latitude/price double\'a çevrilir', () {
      final job = Job.fromJson({
        'id': 'job_1',
        'latitude': 39,
        'longitude': 32,
        'type': 'oneTime',
        'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
        'title': 'Garson',
        'subtitle': 'Alt başlık',
        'price': 500,
      });

      expect(job.latitude, 39.0);
      expect(job.price, 500.0);
    });

    // Backend bilinmeyen bir tip gönderirse uygulama çökmemeli.
    test('tanınmayan type varsayılana düşer', () {
      final job = Job.fromJson({
        'id': 'job_1',
        'latitude': 39.9,
        'longitude': 32.8,
        'type': 'freelance',
        'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
        'title': 'Garson',
        'subtitle': 'Alt başlık',
        'price': 500,
      });

      expect(job.type, JobType.oneTime);
    });

    // Kategori artık enum değil: sunucu tanımadığımız bir kod gönderdiğinde
    // kayıt olduğu gibi korunuyor, yalnızca görünümü varsayılana düşüyor.
    test('tanınmayan kategori kodu korunur, görünümü varsayılana düşer', () {
      final job = Job.fromJson({
        'id': 'job_1',
        'latitude': 39.9,
        'longitude': 32.8,
        'type': 'oneTime',
        'category': {'id': 'cat-9', 'code': 'PLUMBING', 'name': 'Tesisatçılık'},
        'title': 'Tesisatçı',
        'subtitle': 'Alt başlık',
        'price': 500,
      });

      expect(job.category.code, 'PLUMBING');
      expect(job.category.displayName, 'Tesisatçılık');
      expect(job.category.color, AppColors.primaryColor);
      expect(job.category.pinAsset, startsWith('assets/map_pins/'));
    });
  });

  group('JobCategory', () {
    test('her kategorinin Türkçe adı var', () {
      for (final category in JobCategorySeeds.all) {
        expect(category.displayName, isNotEmpty);
      }
      expect(JobCategorySeeds.photography.displayName, 'Fotoğrafçılık');
      expect(JobCategorySeeds.petCare.displayName, 'Hayvan Bakımı');
    });

    test('her kategorinin pin asset yolu benzersiz', () {
      final assets = JobCategorySeeds.all.map((c) => c.pinAsset).toList();
      expect(assets.toSet().length, JobCategorySeeds.all.length);
      for (final asset in assets) {
        expect(asset, startsWith('assets/map_pins/'));
        expect(asset, endsWith('.svg'));
      }
    });

    test('her kategorinin rengi benzersiz', () {
      final colors = JobCategorySeeds.all.map((c) => c.color).toSet();
      expect(colors.length, JobCategorySeeds.all.length);
    });

    // Kod ile backend'deki `job_categories.code` uyuşmazsa hata alınmıyor,
    // kategori sessizce varsayılan görünüme düşüyor. Bu bir kez oldu: kodlar
    // Türkçe slug'dan İngilizceye çevrildiğinde beşin dördü bozulmuştu.
    test('bilinen kodların hiçbiri varsayılan görünüme düşmez', () {
      for (final category in JobCategorySeeds.all) {
        expect(
          category.color,
          isNot(AppColors.primaryColor),
          reason: '${category.code} varsayılan renge düştü',
        );
        expect(
          category.icon,
          isNot(AppIcons.work),
          reason: '${category.code} varsayılan ikona düştü',
        );
      }
    });

    test('kodlar backend seed changeset ile aynı', () {
      expect(JobCategorySeeds.all.map((c) => c.code).toList(), [
        'PHOTOGRAPHY',
        'WAITER',
        'PET_CARE',
        'DESIGN',
        'BARISTA',
      ]);
    });
  });

  group('JobType', () {
    test('Türkçe adları', () {
      expect(JobType.oneTime.displayName, 'Günlük');
      expect(JobType.recurring.displayName, 'Tekrarlı');
    });
  });
}
