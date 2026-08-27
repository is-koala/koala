import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';

import '../../../../../support/fixtures.dart';

void main() {
  late ApplyProvider provider;
  late int notifications;

  setUp(() {
    provider = ApplyProvider();
    notifications = 0;
    provider.addListener(() => notifications++);
  });

  test('başlangıçta başvuru yok', () {
    expect(provider.appliedJobs, isEmpty);
    expect(provider.hasApplied('job_1'), isFalse);
  });

  test('başvuru MyJob\'a çevrilir', () {
    provider.applyToJob(
      buildJob(
        id: 'job_1',
        title: 'Deneyimli Barista',
        price: 15000,
        company: 'Koala Cafe',
        description: 'Latte art yapabilen barista aranıyor.',
      ),
    );

    final applied = provider.appliedJobs.single;
    expect(applied.title, 'Deneyimli Barista');
    expect(applied.company, 'Koala Cafe');
    expect(applied.description, 'Latte art yapabilen barista aranıyor.');
    expect(applied.price, 15000);
    expect(applied.status, MyJobStatus.pending);
  });

  // Kimlik 'applied_' öneki ile kuruluyor; BJobsProvider bu öneki söküp
  // ilanı geri buluyor, o yüzden biçim sözleşmenin parçası.
  test('id applied_ öneki alır', () {
    provider.applyToJob(buildJob(id: 'job_42'));

    expect(provider.appliedJobs.single.id, 'applied_job_42');
    expect(provider.hasApplied('job_42'), isTrue);
  });

  test('açıklama yoksa alt başlığa düşer', () {
    provider.applyToJob(
      buildJob(subtitle: 'Hafta sonu garson aranıyor.', description: null),
    );

    expect(
      provider.appliedJobs.single.description,
      'Hafta sonu garson aranıyor.',
    );
  });

  test('şirket yoksa yer tutucu yazılır', () {
    provider.applyToJob(buildJob(company: null));

    expect(provider.appliedJobs.single.company, 'Bilinmeyen Şirket');
  });

  test('aynı ilana ikinci başvuru yok sayılır', () {
    final job = buildJob(id: 'job_1');
    provider.applyToJob(job);
    provider.applyToJob(job);

    expect(provider.appliedJobs, hasLength(1));
    expect(notifications, 1);
  });

  test('yeni başvuru listenin başına eklenir', () {
    provider.applyToJob(buildJob(id: 'job_1', title: 'İlk'));
    provider.applyToJob(buildJob(id: 'job_2', title: 'İkinci'));

    expect(provider.appliedJobs.map((j) => j.title), ['İkinci', 'İlk']);
  });

  test('tarih gg.aa.yyyy biçiminde yazılır', () {
    provider.applyToJob(buildJob());

    expect(
      provider.appliedJobs.single.date,
      matches(RegExp(r'^\d{2}\.\d{2}\.\d{4}$')),
    );
  });

  test('appliedJobs dışarıdan değiştirilemez', () {
    provider.applyToJob(buildJob());

    expect(() => provider.appliedJobs.clear(), throwsUnsupportedError);
  });
}
