import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/job_applicant.dart';
import 'package:koala/business/features/home/presentation/pages/b_user_profile_page.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';

void main() {
  const applicant = JobApplicant(
    id: 'app-1',
    status: ApplicationStatus.applied,
    user: JobCreator(id: 'worker-1', firstName: 'Ayşe', lastName: 'Yılmaz'),
  );

  test('profil extra başvuran kaydını korur', () {
    final page = BUserProfilePage.fromExtra(applicant);

    expect(page.applicant, applicant);
    expect(page.userId, isNull);
  });

  test('profil extra kullanıcı kimliği ile açılır', () {
    final page = BUserProfilePage.fromExtra('worker-1');

    expect(page.applicant, isNull);
    expect(page.userId, 'worker-1');
  });

  test('beklenmeyen extra tipi ArgumentError atar', () {
    expect(() => BUserProfilePage.fromExtra(42), throwsArgumentError);
  });
}
