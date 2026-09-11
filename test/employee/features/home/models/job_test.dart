import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
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
        salaryType: SalaryType.hourly,
        employerType: JobEmployerType.individual,
        status: JobStatus.closed,
        insuranceRequired: true,
        experienceRequired: true,
        coverImageUrl: 'https://cdn.local/job_42-cover.webp',
        companyId: 'comp_42',
      );

      final restored = Job.fromJson(job.toJson());

      expect(restored.id, job.id);
      expect(restored.title, job.title);
      expect(restored.price, job.price);
      expect(restored.type, job.type);
      expect(restored.category, job.category);
      expect(restored.salaryType, job.salaryType);
      expect(restored.employerType, job.employerType);
      expect(restored.status, job.status);
      expect(restored.insuranceRequired, isTrue);
      expect(restored.experienceRequired, isTrue);
      expect(restored.latitude, job.latitude);
      expect(restored.company, job.company);
      expect(restored.companyId, job.companyId);
      expect(restored.coverImageUrl, job.coverImageUrl);
    });

    test('tarihler ISO 8601 üzerinden turu atlatır', () {
      final job = buildJob(
        startDateTime: DateTime(2026, 2, 15, 10),
        endDateTime: DateTime(2026, 2, 15, 16, 30),
      );

      final restored = Job.fromJson(job.toJson());

      expect(restored.startDateTime, DateTime(2026, 2, 15, 10));
      expect(restored.endDateTime, DateTime(2026, 2, 15, 16, 30));
    });

    test('sunucu gövdesi modele çevrilir', () {
      final job = Job.fromJson({
        'id': 'job_1',
        'title': 'Garson',
        'position': 'Hafta sonu garson',
        'sector': 'Restoran',
        'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
        'employerType': 'COMPANY',
        'type': 'ONE_TIME',
        'salaryType': 'HOURLY',
        'salary': 500,
        'status': 'OPEN',
        'insuranceRequired': true,
        'experienceRequired': false,
        'cityName': 'Ankara',
        'districtName': 'Kızılay',
        'companyName': 'Koala Cafe',
        'latitude': 39.9,
        'longitude': 32.8,
        'coverImageUrl': 'https://cdn.local/job_1-cover.webp',
      });

      expect(job.type, JobType.oneTime);
      expect(job.salaryType, SalaryType.hourly);
      expect(job.employerType, JobEmployerType.company);
      expect(job.status, JobStatus.open);
      expect(job.price, 500.0);
      expect(job.locationLabel, 'Kızılay/Ankara');
      expect(job.hasLocation, isTrue);
      expect(job.coverImageUrl, 'https://cdn.local/job_1-cover.webp');
      expect(job.companyId, isNull);
    });

    test('sözleşmeden düşen ilan durumu açık sayılmaz', () {
      expect(JobStatus.fromCode('IN_PROGRESS'), JobStatus.closed);
      expect(JobStatus.fromCode('COMPLETED'), JobStatus.closed);
      expect(JobStatus.fromCode('DRAFT'), JobStatus.closed);
    });

    // JobSummaryDto.companyId (koala-backend#187) — şirket detayına giden
    // İşlerim satırı bunu okur. companyName tek başına tıklanabilir satır
    // üretmez.
    test('şirket ilanında companyId okunur', () {
      final job = Job.fromJson({
        'id': 'job_1',
        'title': 'Garson',
        'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
        'employerType': 'COMPANY',
        'type': 'ONE_TIME',
        'salary': 500,
        'companyName': 'Koala Cafe',
        'companyId': 'comp_7',
      });

      expect(job.companyId, 'comp_7');
    });

    test('bireysel ilanda companyId yoksa null kalır', () {
      final job = Job.fromJson({
        'id': 'job_1',
        'title': 'Garson',
        'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
        'employerType': 'INDIVIDUAL',
        'type': 'ONE_TIME',
        'salary': 500,
      });

      expect(job.companyId, isNull);
      expect(job.company, isNull);
    });

    // Backend enlem/boylamı opsiyonel döndürüyor; koordinatsız ilan haritada
    // çizilmiyor ama listede görünmeye devam ediyor.
    test('koordinat gelmezse hasLocation false olur', () {
      final job = Job.fromJson({
        'id': 'job_1',
        'title': 'Garson',
        'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
        'type': 'ONE_TIME',
        'salary': 500,
      });

      expect(job.hasLocation, isFalse);
      expect(job.latitude, isNull);
    });

    test('tanınmayan tip varsayılana, durum kapalıya düşer', () {
      final job = Job.fromJson({
        'id': 'job_1',
        'title': 'Garson',
        'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
        'type': 'FREELANCE',
        'salaryType': 'WEEKLY',
        'status': 'PAUSED',
        'salary': 500,
      });

      expect(job.type, JobType.oneTime);
      expect(job.salaryType, SalaryType.daily);
      expect(job.status, JobStatus.closed);
    });

    // Backend'de `subtitle` diye bir alan yok; en açıklayıcıdan en genele
    // doğru düşülüyor.
    test('subtitle pozisyon → sektör → kategori sırasıyla türetilir', () {
      expect(buildJob(position: 'Barista').subtitle, 'Barista');
      expect(buildJob(position: null, sector: 'Restoran').subtitle, 'Restoran');
      expect(buildJob(position: null, sector: null).subtitle, 'Garsonluk');
    });

    test('şehir ve ilçe boşsa konum etiketi null olur', () {
      final job = buildJob(cityName: null, districtName: null);

      expect(job.locationLabel, isNull);
    });
  });

  group('JobDetail serileştirme', () {
    test('sunucu gövdesi modele çevrilir', () {
      final detail = JobDetail.fromJson({
        'id': 'job_1',
        'title': 'Garson',
        'description': 'Hafta sonu garson aranıyor.',
        'duties': 'Servis, kasa',
        'dressCode': 'Siyah pantolon',
        'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
        'type': 'RECURRING',
        'salaryType': 'DAILY',
        'salary': 800,
        'status': 'OPEN',
        'minAge': 18,
        'maxAge': 35,
        'address': {
          'id': 'adr-1',
          'countryId': 'country-1',
          'countryName': 'TÜRKİYE',
          'countryCode': 'TR',
          'cityId': 'city-1',
          'cityName': 'ANKARA',
          'districtId': 'district-1',
          'districtName': 'ÇANKAYA',
          'displayAddress': 'Kızılay Cad. No:1',
          'canonicalVersion': 1,
          'needsReview': false,
        },
        'company': {'id': 'c-1', 'name': 'Koala Cafe'},
        'creator': {'id': 'u-1', 'firstName': 'Ali', 'lastName': 'Veli'},
      });

      expect(detail.type, JobType.recurring);
      expect(detail.duties, 'Servis, kasa');
      expect(detail.minAge, 18);
      expect(detail.addressLabel, 'Kızılay Cad. No:1');
      expect(detail.employerName, 'Koala Cafe');
      expect(detail.company?.name, 'Koala Cafe');
      expect(detail.creator?.fullName, 'Ali Veli');
    });

    // Backend yaş sınırı yokken 0 döndürüyor; arayüz satırı hiç çizmemeli.
    test('yaş sıfırsa sınır yok sayılır', () {
      final detail = JobDetail.fromJson({
        'id': 'job_1',
        'title': 'Garson',
        'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
        'minAge': 0,
        'maxAge': 0,
      });

      expect(detail.minAge, isNull);
      expect(detail.maxAge, isNull);
    });

    test('şirket yoksa ilanı açan kişinin adı kullanılır', () {
      final detail = JobDetail.fromJson({
        'id': 'job_1',
        'title': 'Garson',
        'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
        'creator': {'id': 'u-1', 'firstName': 'Ali', 'lastName': 'Veli'},
      });

      expect(detail.employerName, 'Ali Veli');
    });

    test('açık adres yoksa ilçe/il yazılır', () {
      final detail = JobDetail.fromJson({
        'id': 'job_1',
        'title': 'Garson',
        'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
        'address': {
          'id': 'adr-1',
          'cityName': 'Ankara',
          'districtName': 'Kızılay',
        },
      });

      expect(detail.addressLabel, 'Kızılay/Ankara');
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

  group('AddressPrecision', () {
    test('sunucunun iki değeri okunuyor', () {
      expect(
        AddressPrecision.fromCode('APPROXIMATE'),
        AddressPrecision.approximate,
      );
      expect(AddressPrecision.fromCode('EXACT'), AddressPrecision.exact);
    });

    test('eksik alan yaklaşık sayılıyor', () {
      // Bu alanı hiç göndermeyen bir sunucu sürümü yetkiyi kanıtlamıyor;
      // eksiği kesin saymak yuvarlanmış koordinatı tam adres gibi çizerdi.
      expect(AddressPrecision.fromCode(null), AddressPrecision.approximate);
    });

    test('tanınmayan değer yaklaşık sayılıyor', () {
      expect(
        AddressPrecision.fromCode('STREET_LEVEL'),
        AddressPrecision.approximate,
      );
    });
  });

  group('Job konum kesinliği', () {
    test('sunucu gövdesinden okunuyor', () {
      final job = Job.fromJson({
        'id': 'job_1',
        'latitude': 41.015137,
        'longitude': 28.979530,
        'addressPrecision': 'EXACT',
      });

      expect(job.addressPrecision, AddressPrecision.exact);
    });

    test('alan gelmezse yaklaşık kalıyor', () {
      final job = Job.fromJson({'id': 'job_1', 'latitude': 41.02});

      expect(job.addressPrecision, AddressPrecision.approximate);
    });

    test('toJson → fromJson turu kesinliği koruyor', () {
      final job = buildJob(addressPrecision: AddressPrecision.exact);

      expect(
        Job.fromJson(job.toJson()).addressPrecision,
        AddressPrecision.exact,
      );
    });

    test('kesin konumda belirsizlik yarıçapı sıfır', () {
      // Yuvarlama yoksa belirsizlik de yok; sıfırdan büyük bir yarıçap,
      // kesin bir adresin çevresine olmayan bir daire çizerdi.
      final job = buildJob(
        latitude: 41.015137,
        longitude: 28.979530,
        addressPrecision: AddressPrecision.exact,
      );

      expect(job.approximateRadiusInMeters, 0);
    });

    test('yaklaşık yarıçap yuvarlama hatasını kapsıyor', () {
      // ±0.005° enlem ≈ 557 m; boylam bunun kosinüsüyle daralıyor, köşegen
      // ikisinden de büyük olmalı.
      final job = buildJob(latitude: 41.02, longitude: 28.98);

      expect(job.approximateRadiusInMeters, greaterThan(556));
      expect(job.approximateRadiusInMeters, lessThan(800));
    });
  });

  group('Konum kesinliğinin ekrandaki çözünürlüğü', () {
    test('kesin konumda uzaklık ondalıklı yazılıyor', () {
      final job = buildJob(addressPrecision: AddressPrecision.exact);

      expect(job.distanceLabel(2.34), '2.3 km');
    });

    test('yaklaşık konumda uzaklık tam kilometreye yuvarlanıyor', () {
      // Koordinat ±557 m taşırken "2.3 km" yazmak 100 m çözünürlük iddia
      // eder — harita "yaklaşık" derken listenin ondalık hane söylemesi
      // is-koala/koala#93'ün şikâyetiyle aynı okuma hatası.
      final job = buildJob(addressPrecision: AddressPrecision.approximate);

      expect(job.distanceLabel(2.34), '~2 km');
    });

    test(
      'yaklaşık konumda hata payından küçük uzaklık sayı olarak yazılmıyor',
      () {
        final job = buildJob(addressPrecision: AddressPrecision.approximate);

        expect(job.distanceLabel(0.4), "1 km'den yakın");
      },
    );

    test('kesin koordinat dört haneyle yazılıyor', () {
      final job = buildJob(
        latitude: 41.015137,
        longitude: 28.979530,
        addressPrecision: AddressPrecision.exact,
      );

      expect(job.coordinateLabel, '41.0151, 28.9795');
    });

    test('yaklaşık koordinat sunucunun yuvarladığı hane kadar yazılıyor', () {
      // Dört hane yazmak, olmayan iki hane uydurup ±700 m'lik bir değeri
      // ~11 m kesinlikte göstermek olurdu.
      final job = buildJob(
        latitude: 41.02,
        longitude: 28.98,
        addressPrecision: AddressPrecision.approximate,
      );

      expect(job.coordinateLabel, '41.02, 28.98');
    });
  });

  group('JobDetail konum kesinliği', () {
    test('sunucu gövdesinden okunuyor', () {
      final detail = JobDetail.fromJson({
        'id': 'job_1',
        'addressPrecision': 'EXACT',
      });

      expect(detail.addressPrecision, AddressPrecision.exact);
    });

    test('alan gelmezse yaklaşık kalıyor', () {
      final detail = JobDetail.fromJson({'id': 'job_1'});

      expect(detail.addressPrecision, AddressPrecision.approximate);
    });
  });
}
