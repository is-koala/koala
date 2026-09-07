import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_filter_selection.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/product/models/reference_location.dart';

const _ankara = ReferenceLocation(id: 'city-6', name: 'Ankara');
const _cankaya = ReferenceLocation(id: 'district-1', name: 'Çankaya');

void main() {
  group('JobFilterSelection.toQuery', () {
    test('boş seçim boş sorgu üretiyor', () {
      expect(const JobFilterSelection().toQuery().toQueryParameters(), isEmpty);
    });

    test('seçimler sunucu alanlarına çevriliyor', () {
      final query = JobFilterSelection(
        category: JobCategorySeeds.waiter,
        type: JobType.recurring,
        city: _ankara,
        district: _cankaya,
        salaryType: SalaryType.hourly,
        employerType: JobEmployerType.individual,
        minSalary: 500,
        maxSalary: 2000,
        insuranceRequired: true,
        experienceRequired: false,
        sort: JobSortOption.salaryAsc,
      ).toQuery(searchText: 'garson');

      expect(query.toQueryParameters(), {
        'query': 'garson',
        'categoryId': JobCategorySeeds.waiter.id,
        'cityId': 'city-6',
        'districtId': 'district-1',
        'type': 'RECURRING',
        'salaryType': 'HOURLY',
        'employerType': 'INDIVIDUAL',
        'minSalary': 500.0,
        'maxSalary': 2000.0,
        'insuranceRequired': true,
        'experienceRequired': false,
        'sort': 'salary,asc',
      });
    });

    test('konum yokken yarıçap kutuya çevrilmiyor', () {
      final query = const JobFilterSelection(radiusKm: 5).toQuery();

      expect(query.hasBounds, isFalse);
    });

    test('konum varken yarıçap kutuya çevriliyor', () {
      final query = const JobFilterSelection(
        radiusKm: 5,
      ).toQuery(latitude: 39.92, longitude: 32.85);

      expect(query.hasBounds, isTrue);
      expect(query.minLatitude, lessThan(39.92));
    });
  });

  group('JobFilterSelection.activeFilters', () {
    test('boş seçimde hiç süzgeç yok', () {
      expect(const JobFilterSelection().activeCount, 0);
      expect(const JobFilterSelection().isEmpty, isTrue);
    });

    test('sıralama süzgeç sayılmıyor', () {
      const selection = JobFilterSelection(sort: JobSortOption.titleAsc);

      expect(selection.activeCount, 0);
      expect(selection.isEmpty, isTrue);
    });

    test('ücret alt ve üst sınırı tek süzgeç sayılıyor', () {
      const selection = JobFilterSelection(minSalary: 500, maxSalary: 2000);

      expect(selection.activeCount, 1);
      expect(selection.activeFilters.single.field, JobFilterField.salary);
    });

    test('her seçim çubukta bir çip üretiyor', () {
      final selection = JobFilterSelection(
        category: JobCategorySeeds.waiter,
        type: JobType.oneTime,
        city: _ankara,
        district: _cankaya,
        salaryType: SalaryType.daily,
        employerType: JobEmployerType.company,
        minSalary: 500,
        insuranceRequired: true,
        experienceRequired: true,
        radiusKm: 10,
      );

      expect(selection.activeCount, 10);
      expect(
        selection.activeFilters.map((filter) => filter.label),
        contains('Garsonluk'),
      );
    });

    test('çip etiketleri okunur', () {
      const selection = JobFilterSelection(
        city: _ankara,
        minSalary: 500,
        maxSalary: 2000,
        radiusKm: 10,
        insuranceRequired: true,
      );
      final labels = selection.activeFilters.map((f) => f.label).toList();

      expect(labels, contains('Ankara'));
      expect(labels, contains('500₺ - 2.000₺'));
      expect(labels, contains('10 km içinde'));
      expect(labels, contains('Sigortalı'));
    });

    test('üst sınırsız ücret etiketi açık uçlu yazılıyor', () {
      const selection = JobFilterSelection(minSalary: 2000);

      expect(selection.activeFilters.single.label, '2.000₺ ve üzeri');
    });

    test('alt sınırsız ücret etiketi açık uçlu yazılıyor', () {
      const selection = JobFilterSelection(maxSalary: 500);

      expect(selection.activeFilters.single.label, 'en çok 500₺');
    });
  });

  group('JobFilterSelection.without', () {
    test('tek alan temizleniyor, diğerleri kalıyor', () {
      final selection = JobFilterSelection(
        category: JobCategorySeeds.waiter,
        type: JobType.oneTime,
      );

      final cleared = selection.without(JobFilterField.category);

      expect(cleared.category, isNull);
      expect(cleared.type, JobType.oneTime);
    });

    test('il kaldırılınca ilçe de düşüyor', () {
      const selection = JobFilterSelection(city: _ankara, district: _cankaya);

      final cleared = selection.without(JobFilterField.city);

      expect(cleared.city, isNull);
      expect(cleared.district, isNull);
    });

    test('ücret çipi iki sınırı birden temizliyor', () {
      const selection = JobFilterSelection(minSalary: 500, maxSalary: 2000);

      final cleared = selection.without(JobFilterField.salary);

      expect(cleared.minSalary, isNull);
      expect(cleared.maxSalary, isNull);
    });

    test('sıralama süzgeç temizlemekten etkilenmiyor', () {
      const selection = JobFilterSelection(
        sort: JobSortOption.salaryDesc,
        city: _ankara,
      );

      expect(
        selection.without(JobFilterField.city).sort,
        JobSortOption.salaryDesc,
      );
    });
  });

  group('JobFilterSelection.cleared', () {
    test('bütün süzgeçler sıfırlanıyor, sıralama korunuyor', () {
      final selection = JobFilterSelection(
        category: JobCategorySeeds.waiter,
        city: _ankara,
        minSalary: 500,
        radiusKm: 5,
        sort: JobSortOption.titleAsc,
      );

      final cleared = selection.cleared();

      expect(cleared.isEmpty, isTrue);
      expect(cleared.sort, JobSortOption.titleAsc);
    });
  });

  group('JobFilterSelection.copyWith', () {
    test('null verilen alan temizleniyor', () {
      const selection = JobFilterSelection(city: _ankara, district: _cankaya);

      expect(selection.copyWith(district: null).district, isNull);
      expect(selection.copyWith(district: null).city, _ankara);
    });

    test('verilmeyen alan korunuyor', () {
      const selection = JobFilterSelection(city: _ankara);

      expect(selection.copyWith(minSalary: 100).city, _ankara);
    });
  });
}
