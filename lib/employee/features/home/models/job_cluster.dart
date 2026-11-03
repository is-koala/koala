import 'dart:math';

import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';

/// Haritada tek bir noktada gösterilen ilan grubu.
///
/// Tek ilanlı grup sıradan bir pin; birden fazla ilanlı grup sayı rozetli
/// grup pini olarak çiziliyor.
class JobCluster {
  JobCluster._(this.jobs)
    : assert(jobs.isNotEmpty),
      latitude =
          jobs.map((job) => job.latitude!).reduce((a, b) => a + b) /
          jobs.length,
      longitude =
          jobs.map((job) => job.longitude!).reduce((a, b) => a + b) /
          jobs.length,
      bounds = JobMapBounds(
        minLatitude: jobs.map((job) => job.latitude!).reduce(min),
        maxLatitude: jobs.map((job) => job.latitude!).reduce(max),
        minLongitude: jobs.map((job) => job.longitude!).reduce(min),
        maxLongitude: jobs.map((job) => job.longitude!).reduce(max),
      );

  /// Gruptaki ilanlar, kimliğe göre sıralı.
  final List<Job> jobs;

  /// Grup pininin durduğu nokta: ilanların ortalaması.
  final double latitude;
  final double longitude;

  /// İlanları kapsayan en küçük kutu; gruba dokununca kamera buna yaklaşıyor.
  final JobMapBounds bounds;

  bool get isSingle => jobs.length == 1;

  /// Bütün ilanlar aynı noktada mı. Yaklaşık konumlu ilanlar sunucuda aynı
  /// hücreye yuvarlandığında olur; yakınlaştırmak onları ayırmaz, gruba
  /// dokununca liste açılıyor.
  bool get isStacked =>
      bounds.maxLatitude - bounds.minLatitude < _samePointDegrees &&
      bounds.maxLongitude - bounds.minLongitude < _samePointDegrees;

  /// "Aynı nokta" eşiği: ~1 m. Koordinatlar altı haneye yuvarlı geliyor.
  static const double _samePointDegrees = 0.00001;

  /// Grubun kararlı kimliği: aynı ilanlar her zaman aynı kimliği üretiyor,
  /// harita da pini yeniden kurmak yerine yerinde tutuyor.
  String get id => jobs.map((job) => job.id).join(',');
}

/// İlanları ekranda birbirine yakın olanlar tek pin olacak biçimde gruplar.
///
/// Mesafe **ekran pikseliyle** ölçülüyor, metreyle değil: üst üste binme
/// yakınlaştırma düzeyine bağlı bir görüntü sorunu. Uzaktan bakınca aynı
/// semtteki ilanlar birleşiyor, yaklaşınca ayrılıyor.
///
/// Yöntem açgözlü ve kararlı: ilanlar kimliğe göre sıralanıp sırayla tohum
/// oluyor, tohumun [radius] içindeki atanmamış ilanlar onun grubuna giriyor.
/// Aynı ilanlar ve aynı yakınlaştırma her seferinde aynı grupları veriyor;
/// pinler kamera her durduğunda yer değiştirmiyor. Komşu arama ızgarayla
/// yapılıyor, yani grup kurmak ilan sayısıyla doğrusal büyüyor.
class JobClusterer {
  const JobClusterer._();

  /// İki pinin ayrı durması için gereken ekran mesafesi (mantıksal piksel).
  /// Pin ~50 piksel geniş; daha yakınlar birbirini örtüyor.
  static const double defaultRadius = 60;

  /// Web Mercator'da 0. yakınlaştırmada dünyanın kenarı (piksel).
  static const double _tileSize = 256;

  static List<JobCluster> cluster(
    List<Job> jobs, {
    required double zoom,
    double radius = defaultRadius,
  }) {
    final located = jobs.where((job) => job.hasLocation).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (located.isEmpty) return const [];

    final worldSize = _tileSize * pow(2, zoom);
    final points = [
      for (final job in located) _project(job, worldSize.toDouble()),
    ];

    // Hücre kenarı yarıçap kadar: yarıçap içindeki her komşu tohumun 3×3
    // komşuluğunda.
    final grid = <(int, int), List<int>>{};
    for (var i = 0; i < points.length; i++) {
      grid.putIfAbsent(_cell(points[i], radius), () => []).add(i);
    }

    final assigned = List<bool>.filled(located.length, false);
    final clusters = <JobCluster>[];
    for (var seed = 0; seed < located.length; seed++) {
      if (assigned[seed]) continue;
      assigned[seed] = true;
      final members = [located[seed]];
      final (cx, cy) = _cell(points[seed], radius);

      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final other in grid[(cx + dx, cy + dy)] ?? const <int>[]) {
            if (assigned[other]) continue;
            if (_distance(points[seed], points[other]) > radius) continue;
            assigned[other] = true;
            members.add(located[other]);
          }
        }
      }

      members.sort((a, b) => a.id.compareTo(b.id));
      clusters.add(JobCluster._(members));
    }
    return clusters;
  }

  /// Enlem/boylamı o yakınlaştırmadaki dünya pikseline çevirir.
  static (double, double) _project(Job job, double worldSize) {
    final sinLat = sin(job.latitude!.clamp(-85.0511, 85.0511) * pi / 180);
    final x = (job.longitude! + 180) / 360 * worldSize;
    final y = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi)) * worldSize;
    return (x, y);
  }

  static (int, int) _cell((double, double) point, double radius) =>
      ((point.$1 / radius).floor(), (point.$2 / radius).floor());

  static double _distance((double, double) a, (double, double) b) {
    final dx = a.$1 - b.$1;
    final dy = a.$2 - b.$2;
    return sqrt(dx * dx + dy * dy);
  }
}
