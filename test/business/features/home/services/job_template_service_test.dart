import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/services/job_template_service.dart';
import 'package:koala/employee/features/home/models/job.dart';

import '../../../../support/fake_api.dart';

/// `JobTemplateDto` biçiminde tek bir şablon.
const _template = {
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
  'position': 'Garson',
  'type': 'RECURRING',
  'salaryType': 'HOURLY',
  'salary': 250.5,
  'minAge': 18,
  'maxAge': 40,
  'experienceRequired': true,
  'insuranceRequired': false,
  'createdAt': '2026-09-05T18:30:00Z',
};

void main() {
  group('Şablon listesi', () {
    test('sayfasız düz liste modele çevriliyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [_template],
          },
        ),
      );

      final templates = await JobTemplateService.withClient(
        api.client,
      ).fetchTemplates();

      final request = api.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/users/me/job-templates');
      expect(templates.single.templateName, 'Cumartesi garson');
      expect(templates.single.category?.code, 'GARSON');
      expect(templates.single.type, JobType.recurring);
      expect(templates.single.salaryType, SalaryType.hourly);
      expect(templates.single.salary, 250.5);
    });

    test('veri listesi değilse boş liste dönüyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': null},
        ),
      );

      final templates = await JobTemplateService.withClient(
        api.client,
      ).fetchTemplates();

      expect(templates, isEmpty);
    });
  });

  group('İlandan şablon çıkarma', () {
    test('gövde yalnızca şablon adı ve ilan kimliği taşıyor', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 201,
          body: {'success': true, 'data': _template},
        ),
      );

      final created = await JobTemplateService.withClient(
        api.client,
      ).createFromJob(jobId: 'job-9', templateName: 'Cumartesi garson');

      final request = api.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/users/me/job-templates');
      expect(request.data, {
        'templateName': 'Cumartesi garson',
        'jobId': 'job-9',
      });
      expect(created.id, 'template-1');
    });
  });

  group('Şablon silme', () {
    test('şablon kimliği yola ekleniyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await JobTemplateService.withClient(
        api.client,
      ).deleteTemplate('template-1');

      final request = api.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/users/me/job-templates/template-1');
    });
  });
}
