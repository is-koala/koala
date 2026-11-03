import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job_cluster.dart';

import '../../../../support/fixtures.dart';

void main() {
  // Kadıköy'de ~100 m arayla iki ilan; Sultanahmet ~5 km ötede.
  final moda = buildJob(id: 'moda', latitude: 40.9870, longitude: 29.0260);
  final yakin = buildJob(id: 'yakin', latitude: 40.9878, longitude: 29.0266);
  final uzak = buildJob(id: 'uzak', latitude: 41.0082, longitude: 28.9784);

  List<List<String>> ids(List<JobCluster> clusters) => [
    for (final cluster in clusters) [for (final job in cluster.jobs) job.id],
  ];

  group('JobClusterer', () {
    test('uzaktan bakınca yakın ilanlar tek grupta birleşir', () {
      final clusters = JobClusterer.cluster([moda, yakin, uzak], zoom: 11);

      expect(ids(clusters), [
        ['moda', 'yakin'],
        ['uzak'],
      ]);
    });

    test('yaklaşınca aynı ilanlar ayrılır', () {
      final clusters = JobClusterer.cluster([moda, yakin, uzak], zoom: 18);

      expect(clusters, hasLength(3));
      expect(clusters.every((cluster) => cluster.isSingle), isTrue);
    });

    test('aynı noktadaki ilanlar en yakında da ayrılmaz ve yığın sayılır', () {
      final ikiz = buildJob(id: 'ikiz', latitude: 40.9870, longitude: 29.0260);

      final clusters = JobClusterer.cluster([moda, ikiz], zoom: 21);

      expect(ids(clusters), [
        ['ikiz', 'moda'],
      ]);
      expect(clusters.single.isStacked, isTrue);
    });

    test('ayrı noktalardaki grup yığın sayılmaz', () {
      final cluster = JobClusterer.cluster([moda, yakin], zoom: 11).single;

      expect(cluster.isStacked, isFalse);
    });

    test('sonuç girdi sırasından bağımsızdır', () {
      final first = JobClusterer.cluster([moda, yakin, uzak], zoom: 11);
      final second = JobClusterer.cluster([uzak, yakin, moda], zoom: 11);

      expect(
        second.map((cluster) => cluster.id),
        first.map((cluster) => cluster.id),
      );
    });

    test('grup pini ilanların ortasında, kutusu ilanları kapsıyor', () {
      final cluster = JobClusterer.cluster([moda, yakin], zoom: 11).single;

      expect(cluster.latitude, closeTo((40.9870 + 40.9878) / 2, 1e-9));
      expect(cluster.longitude, closeTo((29.0260 + 29.0266) / 2, 1e-9));
      expect(cluster.bounds.containsPoint(40.9870, 29.0260), isTrue);
      expect(cluster.bounds.containsPoint(40.9878, 29.0266), isTrue);
    });

    test('koordinatsız ilan gruplara girmez', () {
      final konumsuz = buildJob(
        id: 'konumsuz',
        latitude: null,
        longitude: null,
      );

      final clusters = JobClusterer.cluster([konumsuz, moda], zoom: 15);

      expect(ids(clusters), [
        ['moda'],
      ]);
      expect(JobClusterer.cluster([konumsuz], zoom: 15), isEmpty);
    });

    test('grup kimliği aynı ilanlar için kararlı', () {
      final a = JobClusterer.cluster([moda, yakin], zoom: 11).single;
      final b = JobClusterer.cluster([yakin, moda], zoom: 11).single;

      expect(a.id, b.id);
    });
  });
}
