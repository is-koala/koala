import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';
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

    test('yakınlık sıralaması lat/lng ve sort=distance,asc gönderiyor', () {
      const query = JobSearchQuery(
        latitude: 41.008238123,
        longitude: 28.978359456,
        sort: JobSortOption.nearest,
      );

      expect(query.toQueryParameters(), {
        'lat': 41.008238,
        'lng': 28.978359,
        'sort': 'distance,asc',
      });
    });

    test('konum yokken yakınlık sıralaması sort parametresini düşürüyor', () {
      const query = JobSearchQuery(sort: JobSortOption.nearest);

      expect(query.toQueryParameters().containsKey('sort'), isFalse);
      expect(query.toQueryParameters().containsKey('lat'), isFalse);
    });

    test('konum altı ondalığa yuvarlanıyor', () {
      const query = JobSearchQuery(
        latitude: 41.01234567891,
        longitude: 28.97654321098,
      );

      expect(query.toQueryParameters()['lat'], 41.012346);
      expect(query.toQueryParameters()['lng'], 28.976543);
    });

    test('yalnız enlem veya yalnız boylam lat/lng üretmiyor', () {
      expect(
        const JobSearchQuery(
          latitude: 41.0,
        ).toQueryParameters().containsKey('lat'),
        isFalse,
      );
      expect(
        const JobSearchQuery(
          longitude: 29.0,
        ).toQueryParameters().containsKey('lng'),
        isFalse,
      );
    });

    test('başlangıç penceresi ISO Instant olarak gidiyor', () {
      final query = JobSearchQuery(
        startFrom: DateTime.parse('2026-09-14T21:00:00.000Z'),
        startTo: DateTime.parse('2026-09-15T20:59:59.999Z'),
      );

      expect(
        query.toQueryParameters()['startFrom'],
        '2026-09-14T21:00:00.000Z',
      );
      expect(query.toQueryParameters()['startTo'], '2026-09-15T20:59:59.999Z');
    });

    test('pencerenin bir ucu eksikse ikisi de konmuyor', () {
      final query = JobSearchQuery(
        startFrom: DateTime.parse('2026-09-14T21:00:00.000Z'),
      );

      expect(query.toQueryParameters().containsKey('startFrom'), isFalse);
      expect(query.toQueryParameters().containsKey('startTo'), isFalse);
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
        companyId: 'company-7',
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
        bounds: JobMapBounds(
          minLatitude: 39.8,
          maxLatitude: 40.0,
          minLongitude: 32.7,
          maxLongitude: 32.9,
        ),
        sort: JobSortOption.titleAsc,
      );

      expect(query.toQueryParameters(), {
        'query': 'garson',
        'companyId': 'company-7',
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
    test('yalnız sunucunun beyaz listesindeki alanları üretiyor', () {
      final fields = JobSortOption.values.map((option) => option.field).toSet();

      expect(fields, {
        'createdAt',
        'distance',
        'salary',
        'startDateTime',
        'title',
      });
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

    test('tam sayı verilen ücret alanı double olarak saklanıyor', () {
      // Nöbetçi yüzünden parametre `Object?`; `100` yazımı derleniyor ama
      // dönüştürülmezse çalışma anında tip hatası veriyordu.
      final updated = const JobSearchQuery().copyWith(minSalary: 100);

      expect(updated.minSalary, 100.0);
      expect(updated.toQueryParameters()['minSalary'], 100.0);
    });

    test('null verilen alan temizleniyor', () {
      const query = JobSearchQuery(
        query: 'garson',
        companyId: 'company-7',
        categoryId: 'cat-1',
        latitude: 41.0,
        longitude: 29.0,
      );

      final updated = query.copyWith(companyId: null, categoryId: null);

      expect(updated.companyId, isNull);
      expect(updated.categoryId, isNull);
      expect(updated.query, 'garson');
      expect(updated.latitude, 41.0);
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

    test('konum süzgeç sayılmıyor', () {
      const query = JobSearchQuery(latitude: 41.0, longitude: 29.0);

      expect(query.hasFilters, isFalse);
      expect(query.hasOrigin, isTrue);
    });

    test('başlangıç penceresi süzgeç sayılıyor', () {
      final query = JobSearchQuery(
        startFrom: DateTime.parse('2026-09-14T21:00:00.000Z'),
        startTo: DateTime.parse('2026-09-15T20:59:59.999Z'),
      );

      expect(query.hasFilters, isTrue);
      expect(query.hasStartWindow, isTrue);
    });

    test('şirket kimliği süzgeç sayılıyor', () {
      const query = JobSearchQuery(companyId: 'company-7');

      expect(query.hasFilters, isTrue);
    });

    test('sınırlayıcı kutu süzgeç sayılıyor', () {
      const query = JobSearchQuery(
        bounds: JobMapBounds(
          minLatitude: 39.8,
          maxLatitude: 40.0,
          minLongitude: 32.7,
          maxLongitude: 32.9,
        ),
      );

      expect(query.hasFilters, isTrue);
      expect(query.hasBounds, isTrue);
    });

    test('kutusuz sorguda hasBounds kapalı', () {
      expect(const JobSearchQuery().hasBounds, isFalse);
    });
  });

  group('JobSearchQuery.withRadius', () {
    test('yarıçap merkezi çevreleyen bir kutuya çevriliyor', () {
      final query = const JobSearchQuery().withRadius(
        latitude: 39.92,
        longitude: 32.85,
        radiusKm: 5,
      );

      expect(query.bounds!.minLatitude, lessThan(39.92));
      expect(query.bounds!.maxLatitude, greaterThan(39.92));
      expect(query.bounds!.minLongitude, lessThan(32.85));
      expect(query.bounds!.maxLongitude, greaterThan(32.85));
    });

    test('kutu merkeze göre simetrik', () {
      final query = const JobSearchQuery().withRadius(
        latitude: 39.92,
        longitude: 32.85,
        radiusKm: 5,
      );

      expect(
        query.bounds!.maxLatitude - 39.92,
        closeTo(39.92 - query.bounds!.minLatitude, 1e-9),
      );
      expect(
        query.bounds!.maxLongitude - 32.85,
        closeTo(32.85 - query.bounds!.minLongitude, 1e-9),
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

      final ankaraSpan =
          ankara.bounds!.maxLongitude - ankara.bounds!.minLongitude;
      final kuzeySpan = kuzey.bounds!.maxLongitude - kuzey.bounds!.minLongitude;

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
