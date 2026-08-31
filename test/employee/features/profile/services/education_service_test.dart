import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/models/education.dart';
import 'package:koala/employee/features/profile/services/education_service.dart';

import '../../../../support/fake_api.dart';

const Map<String, dynamic> _created = {
  'success': true,
  'data': {
    'id': 'edu_1',
    'universityId': 'uni_1',
    'universityName': 'Boğaziçi Üniversitesi',
    'facultyId': 'fac_1',
    'facultyName': 'Mühendislik Fakültesi',
    'departmentId': 'dep_1',
    'departmentName': 'Bilgisayar Mühendisliği',
    'type': 'GRADUATE',
    'gpa': 3.4,
    'startDate': '2018-09-01',
    'endDate': '2022-06-15',
  },
};

void main() {
  group('EducationService.create', () {
    test('kayıt gövdesi gönderilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(statusCode: 201, body: _created),
      );

      final education = await EducationService.withClient(api.client).create(
        universityId: 'uni_1',
        facultyId: 'fac_1',
        departmentId: 'dep_1',
        type: GradeType.graduate,
        startDate: DateTime(2018, 9),
        gpa: 3.4,
        endDate: DateTime(2022, 6, 15),
      );

      final request = api.requests.single;
      expect(request.path, '/users/me/educations');
      expect(request.method, 'POST');
      expect(request.data, {
        'universityId': 'uni_1',
        'facultyId': 'fac_1',
        'departmentId': 'dep_1',
        'type': 'GRADUATE',
        'gpa': 3.4,
        'startDate': '2018-09-01',
        'endDate': '2022-06-15',
      });
      expect(education.universityName, 'Boğaziçi Üniversitesi');
      expect(education.gpa, 3.4);
    });

    // Alan `double` ve `null` kabul etmiyor; sunucu 0'ı "girilmemiş"
    // olarak okuyor.
    test('not ortalaması verilmezse sıfır gider', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(statusCode: 201, body: _created),
      );

      await EducationService.withClient(api.client).create(
        universityId: 'uni_1',
        facultyId: 'fac_1',
        departmentId: 'dep_1',
        type: GradeType.firstGrade,
        startDate: DateTime(2024, 9),
      );

      final data = api.requests.single.data! as Map<String, dynamic>;
      expect(data['gpa'], 0);
      expect(data['endDate'], isNull);
      expect(data['type'], 'FIRST_GRADE');
    });

    // `toIso8601String` saat de yazıyor ve sunucunun `LocalDate`
    // çözümleyicisi onu reddediyor.
    test('tarihler saatsiz gönderilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(statusCode: 201, body: _created),
      );

      await EducationService.withClient(api.client).create(
        universityId: 'uni_1',
        facultyId: 'fac_1',
        departmentId: 'dep_1',
        type: GradeType.graduate,
        startDate: DateTime(2018, 9, 5, 14, 30),
      );

      final data = api.requests.single.data! as Map<String, dynamic>;
      expect(data['startDate'], '2018-09-05');
    });
  });

  group('EducationService.update', () {
    test('PUT ile kaydın tamamı gönderilir', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(statusCode: 200, body: _created),
      );

      await EducationService.withClient(api.client).update(
        educationId: 'edu_1',
        universityId: 'uni_1',
        facultyId: 'fac_1',
        departmentId: 'dep_1',
        type: GradeType.graduate,
        startDate: DateTime(2018, 9),
      );

      final request = api.requests.single;
      expect(request.path, '/users/me/educations/edu_1');
      expect(request.method, 'PUT');
    });
  });

  group('EducationService.delete', () {
    test('kayıt kimliği yola eklenir', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await EducationService.withClient(api.client).delete('edu_1');

      final request = api.requests.single;
      expect(request.path, '/users/me/educations/edu_1');
      expect(request.method, 'DELETE');
    });
  });
}
