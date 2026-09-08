import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:flutter_svg/flutter_svg.dart';

class JobMarkerGenerator {
  static final Map<JobCategory, BitmapDescriptor> _iconCache = {};

  /// Belirsizlik dairesinin dolgu saydamlığı. Altındaki harita okunur kalmalı;
  /// daire bir alanı işaret ediyor, bir yüzeyi kaplamıyor.
  static const double _areaFillAlpha = 0.14;

  /// Dairenin kenar saydamlığı. Dolgudan belirgin, ama pinin önüne geçmeyecek
  /// kadar; kenar olmadan düşük alfalı dolgu açık haritada kayboluyor.
  static const double _areaStrokeAlpha = 0.5;

  /// Belirsizlik dairesinin kenar kalınlığı (piksel).
  static const int _areaStrokeWidth = 2;

  /// Görünen ilanlar için marker'lar. Anahtar [cacheKeyFor].
  ///
  /// `Set` yerine `Map` dönüyor, çünkü çağıran önbelleği anahtarla tutuyor ve
  /// anahtar marker'dan geri türetilemiyor — kesinlik bayrağı `Marker` üstünde
  /// taşınan bir alan değil.
  static Future<Map<String, Marker>> generateMarkers({
    required List<Job> jobs,
    required void Function(Job job) onMarkerTap,
  }) async {
    final Map<String, Marker> markers = {};

    for (final job in jobs) {
      // Backend enlem/boylamı opsiyonel döndürüyor: adresi koordinata
      // çevrilmemiş ilan haritada gösterilemiyor, atlanıyor.
      if (!job.hasLocation) continue;

      markers[cacheKeyFor(job)] = await _createMarker(job, onMarkerTap);
    }

    return markers;
  }

  /// Yaklaşık konumlu ilanların belirsizlik daireleri.
  ///
  /// Yalnız `APPROXIMATE` ilanlar için çiziliyor: kesin konumda daire, olmayan
  /// bir belirsizliği varmış gibi gösterirdi.
  static Set<Circle> generateAreas({required List<Job> jobs}) {
    return {
      for (final job in jobs)
        if (job.hasLocation &&
            job.addressPrecision == AddressPrecision.approximate)
          Circle(
            circleId: CircleId(job.id),
            center: LatLng(job.latitude!, job.longitude!),
            radius: job.approximateRadiusInMeters,
            fillColor: job.category.color.withValues(alpha: _areaFillAlpha),
            strokeColor: job.category.color.withValues(alpha: _areaStrokeAlpha),
            strokeWidth: _areaStrokeWidth,
          ),
    };
  }

  /// Pin'in konuma bağlandığı nokta.
  ///
  /// Kesin konumda pin **ucundan** bağlanıyor: uç "iş tam burada" demek.
  /// Yaklaşık konumda **ortasından** bağlanıyor, yani pin artık tek bir noktayı
  /// işaret etmiyor, dairenin ortasında duruyor. is-koala/koala#93'ün şikâyeti
  /// tam olarak buydu: yuvarlanmış bir koordinatın ucu gösterilen noktaya
  /// basıyordu.
  static Offset anchorFor(AddressPrecision precision) =>
      precision == AddressPrecision.exact
      ? const Offset(0.5, 1.0)
      : const Offset(0.5, 0.5);

  /// Marker önbelleğinin anahtarı.
  ///
  /// Yalnız `job.id` yetmiyor: aynı ilan, yetki sona erdiğinde (atama
  /// tamamlanınca ya da iptal olunca) aynı id ile ama `APPROXIMATE` bayrağı ve
  /// yuvarlanmış koordinatla geri geliyor. Id'ye bakan bir önbellek eski
  /// **kesin** pini ekranda tutardı — kabul maddesinin "önbellekte kalmış tam
  /// adres yetki sona erdikten sonra gösterilmez" dediği durum budur
  /// (ADR-0003, is-koala/koala#10).
  static String cacheKeyFor(Job job) =>
      '${job.id}|${job.addressPrecision.code}|${job.latitude}|${job.longitude}';

  /// Artık geçerli olmayan marker'ları önbellekten düşürür.
  ///
  /// İki durumu birden kapatıyor: görünen alandan çıkan ilan ve kesinliği ya da
  /// koordinatı değişen ilan. İkincisi anahtarın kendisinden geliyor — eski
  /// anahtar yeni listede yok, o yüzden düşüyor.
  static void evictStale(Map<String, Marker> cache, List<Job> visible) {
    final keys = {for (final job in visible) cacheKeyFor(job)};
    cache.removeWhere((key, _) => !keys.contains(key));
  }

  static Future<Marker> _createMarker(
    Job job,
    void Function(Job job) onMarkerTap,
  ) async {
    final BitmapDescriptor icon = await _getOrCreateIcon(job.category);

    return Marker(
      markerId: MarkerId(job.id),
      position: LatLng(job.latitude!, job.longitude!),
      icon: icon,
      onTap: () => onMarkerTap(job),
      anchor: anchorFor(job.addressPrecision),
    );
  }

  static Future<BitmapDescriptor> _getOrCreateIcon(JobCategory category) async {
    if (_iconCache.containsKey(category)) {
      return _iconCache[category]!;
    }

    final icon = await _createIconFromSvg(category);
    _iconCache[category] = icon;
    return icon;
  }

  static Future<BitmapDescriptor> _createIconFromSvg(
    JobCategory category,
  ) async {
    const double size = 70;
    String svgString = await rootBundle.loadString(category.pinAsset);
    final String categoryColorHex =
        // ignore: deprecated_member_use
        '#${category.color.value.toRadixString(16).substring(2)}';
    svgString = svgString.replaceAll('#82C180', categoryColorHex);
    final PictureInfo pictureInfo = await vg.loadPicture(
      SvgStringLoader(svgString),
      null,
    );
    final double svgWidth = pictureInfo.size.width;
    final double svgHeight = pictureInfo.size.height;
    final double scale = size / svgHeight;
    final double scaledWidth = svgWidth * scale;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    canvas.scale(scale);
    canvas.drawPicture(pictureInfo.picture);
    final ui.Image image = await pictureRecorder.endRecording().toImage(
      scaledWidth.toInt(),
      size.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    pictureInfo.picture.dispose();

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  static void clearCache() {
    _iconCache.clear();
  }
}
