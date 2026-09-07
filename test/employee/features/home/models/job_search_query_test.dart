import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';

void main() {
  group('JobSearchQuery.toQueryParameters', () {
    test('boş sorgu hiçbir parametre üretmiyor', () {
      expect(const JobSearchQuery().toQueryParameters(), isEmpty);
    });

    test('varsayılan sıralamada sort parametresi konmuyor', () {
      const query = JobSearchQuery();

      expect(query.sort, JobSortOption.newest);
      expect(query.toQueryParameters().containsKey('sort'), isFalse);
    });

    test('varsayılan dışı sıralama sunucunun beklediği dizeyi üretiyor', () {
      const query = JobSearchQuery(sort: JobSortOption.salaryDesc);

      expect(query.toQueryParameters()['sort'], 'salary,desc');
    });

    test('yalnız boşluktan ibaret arama metni atılıyor', () {
      const query = JobSearchQuery(query: '   ');

      expect(query.toQueryParameters().containsKey('query'), isFalse);
    });

    test('arama metni kırpılarak gönderiliyor', () {
      const query = JobSearchQuery(query: '  garson ');

      expect(query.toQueryParameters()['query'], 'garson');
    });

    test('dolu alanların hepsi backend adlarıyla gidiyor', () {
      const query = JobSearchQuery(
        query: 'garson',
        categoryId: 'cat-1',
        cityId: 'city-6',
        districtId: 'district-9',
        type: JobType.recurring,
        salaryType: SalaryType.hourly,
        employerType: JobEmployerType.individual,
        minSalary: 500,
        maxSalary: 2000,
        insuranceRequired: true,
        experienceRequired: false,
        minLatitude: 39.8,
        maxLatitude: 40.0,
        minLongitude: 32.7,
        maxLongitude: 32.9,
        sort: JobSortOption.titleAsc,
      );

      expect(query.toQueryParameters(), {
        'query': 'garson',
        'categoryId': 'cat-1',
        'cityId': 'city-6',
        'districtId': 'district-9',
        'type': 'RECURRING',
        'salaryType': 'HOURLY',
        'employerType': 'INDIVIDUAL',
        'minSalary': 500.0,
        'maxSalary': 2000.0,
        'insuranceRequired': true,
        'experienceRequired': false,
        'minLatitude': 39.8,
        'maxLatitude': 40.0,
        'minLongitude': 32.7,
        'maxLongitude': 32.9,
        'sort': 'title,asc',
      });
    });
  });

  group('JobSortOption', () {
    test('yalnız sunucunun beyaz listesindeki dört alanı üretiyor', () {
      final fields = JobSortOption.values.map((option) => option.field).toSet();

      expect(fields, {'createdAt', 'salary', 'startDateTime', 'title'});
    });

    test('her seçenek `alan,yön` biçiminde parametre üretiyor', () {
      for (final option in JobSortOption.values) {
        expect(option.parameter, matches(RegExp(r'^\w+,(asc|desc)$')));
      }
    });

    test('varsayılan yalnızca sunucunun DEFAULT_SORT karşılığı', () {
      final defaults = JobSortOption.values.where((option) => option.isDefault);

      expect(defaults, [JobSortOption.newest]);
      expect(JobSortOption.newest.parameter, 'createdAt,desc');
    });
  });

  group('JobSearchQuery.copyWith', () {
    test('verilmeyen alan korunuyor', () {
      const query = JobSearchQuery(query: 'garson', categoryId: 'cat-1');

      final updated = query.copyWith(categoryId: 'cat-2');

      expect(updated.query, 'garson');
      expect(updated.categoryId, 'cat-2');
    });

    test('null verilen alan temizleniyor', () {
      const query = JobSearchQuery(query: 'garson', categoryId: 'cat-1');

      final updated = query.copyWith(categoryId: null);

      expect(updated.categoryId, isNull);
      expect(updated.query, 'garson');
    });
  });

  group('JobSearchQuery.hasQuery / hasFilters', () {
    test('boş sorguda ikisi de kapalı', () {
      const query = JobSearchQuery();

      expect(query.hasQuery, isFalse);
      expect(query.hasFilters, isFalse);
    });

    test('arama metni süzgeç sayılmıyor', () {
      const query = JobSearchQuery(query: 'garson');

      expect(query.hasQuery, isTrue);
      expect(query.hasFilters, isFalse);
    });

    test('sıralama süzgeç sayılmıyor', () {
      const query = JobSearchQuery(sort: JobSortOption.salaryAsc);

      expect(query.hasFilters, isFalse);
    });

    test('sınırlayıcı kutu süzgeç sayılıyor', () {
      const query = JobSearchQuery(minLatitude: 39.8, maxLatitude: 40.0);

      expect(query.hasFilters, isTrue);
    });
  });

  group('JobSearchQuery.withRadius', () {
    test('yarıçap merkezi çevreleyen bir kutuya çevriliyor', () {
      final query = const JobSearchQuery().withRadius(
        latitude: 39.92,
        longitude: 32.85,
        radiusKm: 5,
      );

      expect(query.minLatitude, lessThan(39.92));
      expect(query.maxLatitude, greaterThan(39.92));
      expect(query.minLongitude, lessThan(32.85));
      expect(query.maxLongitude, greaterThan(32.85));
    });

    test('kutu merkeze göre simetrik', () {
      final query = const JobSearchQuery().withRadius(
        latitude: 39.92,
        longitude: 32.85,
        radiusKm: 5,
      );

      expect(
        query.maxLatitude! - 39.92,
        closeTo(39.92 - query.minLatitude!, 1e-9),
      );
      expect(
        query.maxLongitude! - 32.85,
        closeTo(32.85 - query.minLongitude!, 1e-9),
      );
    });

    test('enlem yükseldikçe boylam payı genişliyor', () {
      final ankara = const JobSearchQuery().withRadius(
        latitude: 39.92,
        longitude: 32.85,
        radiusKm: 5,
      );
      final kuzey = const JobSearchQuery().withRadius(
        latitude: 60.0,
        longitude: 32.85,
        radiusKm: 5,
      );

      final ankaraSpan = ankara.maxLongitude! - ankara.minLongitude!;
      final kuzeySpan = kuzey.maxLongitude! - kuzey.minLongitude!;

      expect(kuzeySpan, greaterThan(ankaraSpan));
    });

    test('kutu sorgunun geri kalanını bozmuyor', () {
      final query = const JobSearchQuery(
        query: 'garson',
        categoryId: 'cat-1',
      ).withRadius(latitude: 39.92, longitude: 32.85, radiusKm: 5);

      expect(query.query, 'garson');
      expect(query.categoryId, 'cat-1');
    });
  });
}
