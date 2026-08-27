import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';

import '../../../../support/fixtures.dart';

void main() {
  group('Job serileştirme', () {
    test('toJson → fromJson turu alanları korur', () {
      final job = buildJob(
        id: 'job_42',
        title: 'Deneyimli Barista',
        price: 15000,
        type: JobType.recurring,
        category: JobCategory.barista,
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
        category: JobCategory.photography,
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
        'category': 'waiter',
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
        'category': 'waiter',
        'title': 'Garson',
        'subtitle': 'Alt başlık',
        'price': 500,
      });

      expect(job.latitude, 39.0);
      expect(job.price, 500.0);
    });

    // Backend bilinmeyen bir enum değeri gönderirse uygulama çökmemeli.
    test('tanınmayan type/category varsayılana düşer', () {
      final job = Job.fromJson({
        'id': 'job_1',
        'latitude': 39.9,
        'longitude': 32.8,
        'type': 'freelance',
        'category': 'plumbing',
        'title': 'Garson',
        'subtitle': 'Alt başlık',
        'price': 500,
      });

      expect(job.type, JobType.oneTime);
      expect(job.category, JobCategory.waiter);
    });
  });

  group('JobCategory', () {
    test('her kategorinin Türkçe adı var', () {
      for (final category in JobCategory.values) {
        expect(category.displayName, isNotEmpty);
      }
      expect(JobCategory.photography.displayName, 'Fotoğrafçılık');
      expect(JobCategory.petCare.displayName, 'Hayvan Bakımı');
    });

    test('her kategorinin pin asset yolu benzersiz', () {
      final assets = JobCategory.values.map((c) => c.pinAsset).toList();
      expect(assets.toSet().length, JobCategory.values.length);
      for (final asset in assets) {
        expect(asset, startsWith('assets/map_pins/'));
        expect(asset, endsWith('.svg'));
      }
    });

    test('her kategorinin rengi benzersiz', () {
      final colors = JobCategory.values.map((c) => c.color).toSet();
      expect(colors.length, JobCategory.values.length);
    });
  });

  group('JobType', () {
    test('Türkçe adları', () {
      expect(JobType.oneTime.displayName, 'Günlük');
      expect(JobType.recurring.displayName, 'Tekrarlı');
    });
  });
}
