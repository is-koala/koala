import 'dart:ui' show Brightness;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_marker_generator.dart';

/// Haritada duran pinlerin önbelleği.
///
/// Tek bir değişmezi var ve tamamı burada duruyor: **önbellekte duran bir pin,
/// onu doğuran ilanın kimliği, kesinliği ve koordinatı ile birlikte durur.**
/// Bu üçlüden biri değiştiğinde eski pin kullanılamaz.
///
/// Neden ayrı bir nesne: değişmez eskiden ikiye bölünmüştü — `Map<String,
/// Marker>` sayfada, anahtar üreteci ve tahliye politikası üreticide statik
/// duruyordu. Tahliye çağıranın map'ini dışarıdan mutasyona uğratıyordu ve
/// "yazarken kullanılan anahtar ile tahliye ederken kullanılan anahtar aynı"
/// olduğunu tip değil teamül tutuyordu. Sayfanın id'ye bakan bir map tutmasına
/// engel yoktu; is-koala/koala#10'un "önbellekte kalmış tam adres yetki sona
/// erdikten sonra gösterilmez" maddesini sessizce düşüren kusur tam buydu.
/// Artık map dışarı hiç çıkmıyor, anahtarı da yalnız bu sınıf üretiyor.
class JobMarkerCache {
  /// Anahtar [_keyFor]. Dışarı **sızmıyor**: sızdığı anda çağıran onu
  /// `job.id` ile indekslemeye başlayabilir.
  final Map<String, Marker> _markers = {};

  /// Önbellekteki pinlerin çizildiği tema. Tema değişince bütün pinler
  /// geçersiz: kenar rengi temaya bağlı.
  Brightness? _brightness;

  /// Önbellekte duran pin sayısı; testler ve teşhis için.
  int get length => _markers.length;

  /// [jobs] için haritaya verilecek pin kümesi.
  ///
  /// Eksikleri üretir, artık listede olmayan **her** anahtarı düşürür ve
  /// sonucu döndürür. Kimliği aynı ama kesinliği ya da koordinatı değişmiş bir
  /// ilan "eksik" sayılır: anahtarı farklıdır, eskisi de aynı adımda düşer.
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
      // Backend enlem/boylamı opsiyonel döndürüyor: adresi koordinata
      // çevrilmemiş ilan haritada gösterilemiyor, atlanıyor.
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

  /// Önbelleğin anahtarı.
  ///
  /// Yalnız `job.id` yetmiyor: aynı ilan, yetki sona erdiğinde (atama
  /// tamamlanınca ya da iptal olunca) aynı id ile ama `APPROXIMATE` bayrağı ve
  /// yuvarlanmış koordinatla geri geliyor. Id'ye bakan bir önbellek eski
  /// **kesin** pini ekranda tutardı — kabul maddesinin "önbellekte kalmış tam
  /// adres yetki sona erdikten sonra gösterilmez" dediği durum budur
  /// (ADR-0003, is-koala/koala#10).
  ///
  /// Koordinat **ve** bayrak birlikte duruyor. Bayrak tek başına yetmezdi:
  /// sunucu aynı kesinlikte yeni bir koordinat gönderebilir. Koordinat da tek
  /// başına yetmezdi: kesinlik pinin bağlanma noktasını değiştiriyor, yani iki
  /// kesinlik aynı noktada bile **farklı** pin çiziyor.
  static String _keyFor(Job job) =>
      '${job.id}|${job.addressPrecision.code}|${job.latitude}|${job.longitude}';
}
