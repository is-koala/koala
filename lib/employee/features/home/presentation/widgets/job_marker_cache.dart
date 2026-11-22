import 'dart:ui' show Brightness;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_marker_generator.dart';

/// Haritadaki pinlerin önbelleği. Tek değişmezi: **pin, ilanın kimliği,
/// kesinliği ve koordinatıyla birlikte durur**; biri değişince eski pin
/// kullanılamaz. Map ve anahtar dışarı çıkmıyor; id'ye bakan bir map yetki
/// bittikten sonra tam adresi gösterirdi (#10).
class JobMarkerCache {
  /// Dışarı **sızmıyor**: sızarsa çağıran `job.id` ile indekslemeye başlar.
  final Map<String, Marker> _markers = {};

  /// Tema değişince hepsi geçersiz: kenar rengi temaya bağlı.
  Brightness? _brightness;

  int get length => _markers.length;

  /// Eksikleri üretir, listede olmayan **her** anahtarı düşürür. Kesinliği ya
  /// da koordinatı değişen ilanın anahtarı farklıdır, eskisi aynı adımda düşer.
  Future<Set<Marker>> markersFor({
    required List<Job> jobs,
    required void Function(Job job) onMarkerTap,
    Brightness brightness = Brightness.light,
  }) async {
    if (_brightness != brightness) {
      _markers.clear();
      _brightness = brightness;
    }

    for (final job in jobs) {
      // Koordinatsız ilan atlanır.
      if (!job.hasLocation) continue;

      final key = _keyFor(job);
      if (_markers.containsKey(key)) continue;

      _markers[key] = await JobMarkerGenerator.markerFor(
        job,
        onMarkerTap,
        brightness: brightness,
      );
    }

    final live = {
      for (final job in jobs)
        if (job.hasLocation) _keyFor(job),
    };
    _markers.removeWhere((key, _) => !live.contains(key));

    return _markers.values.toSet();
  }

  /// Anahtar: id + kesinlik + koordinat. Yetki bitince aynı id `APPROXIMATE` ve
  /// yuvarlanmış koordinatla geri geliyor; yalnız id eski **kesin** pini
  /// tutardı (ADR-0003, #10). Bayrak tek başına yetmez (aynı kesinlikte yeni
  /// koordinat), koordinat da yetmez (kesinlik bağlanma noktasını
  /// değiştiriyor).
  static String _keyFor(Job job) =>
      '${job.id}|${job.addressPrecision.code}|${job.latitude}|${job.longitude}';
}
