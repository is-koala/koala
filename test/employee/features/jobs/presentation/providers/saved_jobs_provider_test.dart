import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/jobs/presentation/providers/saved_jobs_provider.dart';

import '../../../../../support/fixtures.dart';

void main() {
  late SavedJobsProvider provider;
  late int notifications;

  setUp(() {
    provider = SavedJobsProvider();
    notifications = 0;
    provider.addListener(() => notifications++);
  });

  test('başlangıçta boş', () {
    expect(provider.savedJobs, isEmpty);
    expect(provider.isSaved('job_1'), isFalse);
  });

  test('toggleSave ilk çağrıda kaydeder', () {
    provider.toggleSave(buildJob(id: 'job_1'));

    expect(provider.savedJobs, hasLength(1));
    expect(provider.isSaved('job_1'), isTrue);
    expect(notifications, 1);
  });

  test('toggleSave ikinci çağrıda kaydı kaldırır', () {
    final job = buildJob(id: 'job_1');
    provider.toggleSave(job);
    provider.toggleSave(job);

    expect(provider.savedJobs, isEmpty);
    expect(provider.isSaved('job_1'), isFalse);
    expect(notifications, 2);
  });

  // Aynı ilanın farklı bir kopyası gelirse (örneğin listeden ve detaydan)
  // kimlik id üzerinden kurulduğu için ikinci kayıt oluşmamalı.
  test('aynı id\'li farklı nesne kopya kayıt açmaz', () {
    provider.toggleSave(buildJob(id: 'job_1', title: 'Garson'));
    provider.toggleSave(buildJob(id: 'job_1', title: 'Garson (güncel)'));

    expect(provider.savedJobs, isEmpty);
  });

  test('birden fazla ilan bağımsız tutulur', () {
    provider.toggleSave(buildJob(id: 'job_1'));
    provider.toggleSave(buildJob(id: 'job_2'));
    provider.toggleSave(buildJob(id: 'job_1'));

    expect(provider.savedJobs, hasLength(1));
    expect(provider.isSaved('job_1'), isFalse);
    expect(provider.isSaved('job_2'), isTrue);
  });

  test('removeJob kaydı siler', () {
    provider.toggleSave(buildJob(id: 'job_1'));
    provider.removeJob('job_1');

    expect(provider.savedJobs, isEmpty);
    expect(notifications, 2);
  });

  test('removeJob olmayan id ile çağrılınca listeyi bozmaz', () {
    provider.toggleSave(buildJob(id: 'job_1'));
    provider.removeJob('yok_boyle_bir_id');

    expect(provider.savedJobs, hasLength(1));
  });

  test('savedJobs dışarıdan değiştirilemez', () {
    provider.toggleSave(buildJob(id: 'job_1'));

    expect(
      () => provider.savedJobs.add(buildJob(id: 'job_2')),
      throwsUnsupportedError,
    );
  });
}
