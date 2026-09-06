import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/job_template.dart';
import 'package:koala/employee/features/home/models/job.dart';

/// `JobTemplateDto` biçiminde tam bir şablon yanıtı.
const _templateJson = {
  'id': 'template-1',
  'templateName': 'Cumartesi garson',
  'companyId': 'company-1',
  'category': {
    'id': 'category-1',
    'name': 'Garson',
    'code': 'GARSON',
    'requiresInsurance': false,
  },
  'title': 'Hafta sonu garson',
  'description': 'Cumartesi akşam servisi.',
  'sector': 'Yiyecek & İçecek',
  'position': 'Garson',
  'duties': 'Servis ve masa toplama',
  'dressCode': 'Siyah pantolon, beyaz gömlek',
  'type': 'ONE_TIME',
  'salaryType': 'DAILY',
  'salary': 1500,
  'minAge': 18,
  'maxAge': 40,
  'experienceRequired': true,
  'insuranceRequired': false,
  'createdAt': '2026-09-05T18:30:00Z',
};

void main() {
  group('JobTemplate JSON', () {
    test('sunucu yanıtındaki bütün alanlar modele geçiyor', () {
      final template = JobTemplate.fromJson(_templateJson);

      expect(template.id, 'template-1');
      expect(template.templateName, 'Cumartesi garson');
      expect(template.companyId, 'company-1');
      expect(template.category?.code, 'GARSON');
      expect(template.title, 'Hafta sonu garson');
      expect(template.description, 'Cumartesi akşam servisi.');
      expect(template.sector, 'Yiyecek & İçecek');
      expect(template.position, 'Garson');
      expect(template.duties, 'Servis ve masa toplama');
      expect(template.dressCode, 'Siyah pantolon, beyaz gömlek');
      expect(template.type, JobType.oneTime);
      expect(template.salaryType, SalaryType.daily);
      expect(template.salary, 1500);
      expect(template.minAge, 18);
      expect(template.maxAge, 40);
      expect(template.experienceRequired, isTrue);
      expect(template.insuranceRequired, isFalse);
      expect(template.createdAt, DateTime.utc(2026, 9, 5, 18, 30));
    });

    test('gidiş dönüş aynı değerleri koruyor', () {
      final template = JobTemplate.fromJson(_templateJson);
      final roundTripped = JobTemplate.fromJson(template.toJson());

      expect(roundTripped.id, template.id);
      expect(roundTripped.templateName, template.templateName);
      expect(roundTripped.companyId, template.companyId);
      expect(roundTripped.category, template.category);
      expect(roundTripped.title, template.title);
      expect(roundTripped.description, template.description);
      expect(roundTripped.sector, template.sector);
      expect(roundTripped.position, template.position);
      expect(roundTripped.duties, template.duties);
      expect(roundTripped.dressCode, template.dressCode);
      expect(roundTripped.type, template.type);
      expect(roundTripped.salaryType, template.salaryType);
      expect(roundTripped.salary, template.salary);
      expect(roundTripped.minAge, template.minAge);
      expect(roundTripped.maxAge, template.maxAge);
      expect(roundTripped.experienceRequired, template.experienceRequired);
      expect(roundTripped.insuranceRequired, template.insuranceRequired);
      expect(roundTripped.createdAt, template.createdAt);
    });

    test('eksik alanlar modeli düşürmüyor', () {
      final template = JobTemplate.fromJson(const {
        'id': 'template-2',
        'templateName': 'Bireysel temizlik',
      });

      expect(template.category, isNull);
      expect(template.companyId, isNull);
      expect(template.title, isNull);
      expect(template.salary, isNull);
      expect(template.minAge, isNull);
      expect(template.experienceRequired, isFalse);
      expect(template.insuranceRequired, isFalse);
      expect(template.createdAt, isNull);
      // Sunucu bu iki alanı hep dolduruyor; yine de varsayılana düşmeli ki
      // eksik bir yanıt formu bozmasın.
      expect(template.type, JobType.oneTime);
      expect(template.salaryType, SalaryType.daily);
    });
  });

  group('Şablonun forma uygulanması', () {
    const insuredCategory = JobCategory(
      id: 'category-1',
      name: 'Kurye',
      code: 'KURYE',
      requiresInsurance: true,
    );
    const plainCategory = JobCategory(
      id: 'category-2',
      name: 'Garson',
      code: 'GARSON',
    );

    test('kurumsal işverende kategori ve sigorta olduğu gibi geliyor', () {
      const template = JobTemplate(
        id: 'template-1',
        templateName: 'Kurye',
        category: insuredCategory,
        insuranceRequired: true,
      );

      final applied = template.applyFor(isCompanyJob: true);

      expect(applied.category, insuredCategory);
      expect(applied.insuranceRequired, isTrue);
      expect(applied.warning, isNull);
    });

    test(
      'bireysel işverende sigorta zorunlu kategori boş kalıyor ve uyarılıyor',
      () {
        const template = JobTemplate(
          id: 'template-1',
          templateName: 'Kurye',
          category: insuredCategory,
          insuranceRequired: true,
        );

        final applied = template.applyFor(isCompanyJob: false);

        // Sessizce başka bir kategoriye ya da sigortasız hâline çekilmiyor:
        // kullanıcı kategoriyi kendisi seçmeli.
        expect(applied.category, isNull);
        expect(applied.insuranceRequired, isFalse);
        expect(applied.warning, isNotNull);
        expect(applied.warning, contains('Kurye'));
      },
    );

    test('bireysel işverende sigorta tercihi düşürülünce de uyarılıyor', () {
      const template = JobTemplate(
        id: 'template-1',
        templateName: 'Garson',
        category: plainCategory,
        insuranceRequired: true,
      );

      final applied = template.applyFor(isCompanyJob: false);

      expect(applied.category, plainCategory);
      expect(applied.insuranceRequired, isFalse);
      expect(applied.warning, isNotNull);
    });

    test('bireysel işverende sigortasız şablon uyarısız uygulanıyor', () {
      const template = JobTemplate(
        id: 'template-1',
        templateName: 'Garson',
        category: plainCategory,
      );

      final applied = template.applyFor(isCompanyJob: false);

      expect(applied.category, plainCategory);
      expect(applied.insuranceRequired, isFalse);
      expect(applied.warning, isNull);
    });
  });
}
