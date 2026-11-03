import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_cluster.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_map_style.dart';
import 'package:reicon_flutter/reicon_flutter.dart';

/// İlan pinlerini ve yaklaşık konum dairelerini üretir.
///
/// Pin bir dosyadan okunmuyor, burada kuruluyor: tek bir damla şekli,
/// kategorinin rengiyle dolu, ince beyaz kenarlı; ortasında kategorinin liste
/// kartında da görünen Reicon ikonu (`JobCategoryStyle.icon`), Filled
/// ağırlığında ve beyaz. Böylece bütün pinler aynı çizgi ailesinden geliyor,
/// harita ile liste aynı ikonu gösteriyor ve tanınmayan bir kategori de
/// nötr ikonla düzgün bir pin alıyor.
class JobMarkerGenerator {
  /// Pin görselleri kategori **ve tema** çiftine göre saklanıyor: kenar rengi
  /// temaya bağlı (`AppMapStyle.pinRim`), açık temanın görseli koyuda
  /// kullanılamaz.
  static final Map<(JobCategory, Brightness), BitmapDescriptor> _iconCache = {};

  /// Grup pinleri etiket ("7", "99+") ve temaya göre saklanıyor.
  static final Map<(String, Brightness), BitmapDescriptor> _clusterIconCache =
      {};

  /// Grup pininin çapı (mantıksal piksel). Tek pinle aynı boyda; grup
  /// haritada daha "önemli" görünmesin, yalnız farklı görünsün.
  static const double _clusterDiameter = 50;

  /// Üç karakterlik etikette ("99+") dairenin büyüdüğü oran.
  static const double _clusterWideScale = 1.15;

  /// Grup pininin beyaz kenarı (mantıksal piksel); tek pinin kenarıyla aynı
  /// görsel kalınlıkta.
  static const double _clusterStroke = 3;

  /// Sayının yazı boyutu (mantıksal piksel). Tuval temayı okuyamadığı için
  /// font burada adıyla veriliyor.
  static const double _clusterFontSize = 18;

  /// Rozetin gösterdiği en büyük sayı; üstü "99+".
  static const int _clusterMaxCount = 99;

  /// Grup pini tek pinlerin üstünde çiziliyor: iki gruptan biri tek bir pinin
  /// altında kalırsa sayısı okunmaz.
  static const int _clusterZIndex = 1;

  /// Damla şekli, 396 × 568 birimlik bir çerçevede; daire kısmının merkezi
  /// (198, 198), yarıçapı 198.
  static const String _pinPath =
      'M395.89 197.95C395.89 320.68 197.95 567.78 197.95 567.78'
      'C197.95 567.78 0 333.38 0 197.95C0 88.6201 88.6201 0 197.95 0'
      'C307.28 0 395.89 88.6201 395.89 197.95Z';

  /// Beyaz kenar kalınlığı (şekil birimi). Pini her iki tema zemininden de
  /// ayırıyor; görünür çerçeve kenarın yarısı kadar dışarı genişletiliyor.
  static const double _pinStroke = 20;

  /// İkonun dairedeki kenar uzunluğu (şekil birimi); daire çapının ~%53'ü.
  static const double _pinIconSize = 210;

  /// Reicon ikonları 24 × 24 birimlik bir çerçevede çiziliyor.
  static const double _reiconGrid = 24;

  /// Pinin ekrandaki yüksekliği (mantıksal piksel).
  static const double _pinHeight = 70;

  /// Ekran yoğunluğu okunamazsa (test, görünüm henüz yok) kullanılan oran;
  /// bugünkü telefonların çoğu 3x.
  static const double _fallbackPixelRatio = 3;

  /// Pinin çizildiği yoğunluk. Görüntü bu oranda üretilip haritaya aynı oranla
  /// veriliyor: oran verilmezse eklenti görüntüyü 1x sayıyor ve 70 piksellik
  /// pini 3x ekranda üç kat büyütüp pikselli gösteriyor.
  static double get _pixelRatio =>
      ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ??
      _fallbackPixelRatio;

  /// Belirsizlik dairesinin dolgu saydamlığı. Altındaki harita okunur kalmalı;
  /// daire bir alanı işaret ediyor, bir yüzeyi kaplamıyor.
  static const double _areaFillAlpha = 0.14;

  /// Dairenin kenar saydamlığı. Dolgudan belirgin, ama pinin önüne geçmeyecek
  /// kadar; kenar olmadan düşük alfalı dolgu açık haritada kayboluyor.
  static const double _areaStrokeAlpha = 0.5;

  /// Birden fazla ilanın grup pini: Koala yeşili, temaya göre kenarlı daire
  /// ve ilan sayısı.
  static Future<Marker> clusterMarkerFor(
    JobCluster cluster,
    void Function(JobCluster cluster) onClusterTap, {
    Brightness brightness = Brightness.light,
  }) async {
    final label = clusterLabel(cluster.jobs.length);
    final icon = _clusterIconCache[(label, brightness)] ??=
        await _createClusterIcon(label, brightness);
    return Marker(
      markerId: MarkerId('cluster:${cluster.id}'),
      position: LatLng(cluster.latitude, cluster.longitude),
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      zIndexInt: _clusterZIndex,
      onTap: () => onClusterTap(cluster),
    );
  }

  /// Rozette yazan metin.
  @visibleForTesting
  static String clusterLabel(int count) =>
      count > _clusterMaxCount ? '$_clusterMaxCount+' : '$count';

  static Future<BitmapDescriptor> _createClusterIcon(
    String label,
    Brightness brightness,
  ) async {
    final pixelRatio = _pixelRatio;
    final logical =
        _clusterDiameter * (label.length > 2 ? _clusterWideScale : 1);
    final size = (logical * pixelRatio).roundToDouble();
    final center = Offset(size / 2, size / 2);
    final stroke = _clusterStroke * pixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas
      ..drawCircle(
        center,
        size / 2,
        Paint()..color = AppMapStyle.pinRim(brightness),
      )
      ..drawCircle(
        center,
        size / 2 - stroke,
        Paint()..color = AppColors.primaryColor,
      );

    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: AppColors.onAccent,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: _clusterFontSize * pixelRatio,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    text.dispose();

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }

  /// Belirsizlik dairesinin kenar kalınlığı (piksel).
  static const int _areaStrokeWidth = 2;

  /// Tek bir ilanın pini.
  ///
  /// Önbellekleme burada **yok**: hangi pinin saklanacağına ve ne zaman
  /// düşürüleceğine `JobMarkerCache` karar veriyor. Bu sınıf pini nasıl
  /// çizeceğini biliyor, ne kadar yaşayacağını değil.
  ///
  /// Çağıran `job.hasLocation`'ı doğrulamış olmalı.
  static Future<Marker> markerFor(
    Job job,
    void Function(Job job) onMarkerTap, {
    Brightness brightness = Brightness.light,
  }) async {
    final BitmapDescriptor icon = await _getOrCreateIcon(
      job.category,
      brightness,
    );

    return Marker(
      markerId: MarkerId(job.id),
      position: LatLng(job.latitude!, job.longitude!),
      icon: icon,
      onTap: () => onMarkerTap(job),
      anchor: anchorFor(job.addressPrecision),
    );
  }

  /// Yaklaşık konumlu ilanların belirsizlik daireleri.
  ///
  /// Yalnız `APPROXIMATE` ilanlar için çiziliyor: kesin konumda daire, olmayan
  /// bir belirsizliği varmış gibi gösterirdi.
  static Set<Circle> generateAreas({required List<Job> jobs}) {
    return {
      for (final job in jobs)
        if (job.hasLocation && job.addressPrecision.isApproximate)
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
      precision.isApproximate ? const Offset(0.5, 0.5) : const Offset(0.5, 1.0);

  static Future<BitmapDescriptor> _getOrCreateIcon(
    JobCategory category,
    Brightness brightness,
  ) async {
    return _iconCache[(category, brightness)] ??= await _createIconFromSvg(
      category,
      brightness,
    );
  }

  /// Bir kategorinin pin SVG'si.
  ///
  /// Kategori ikonunun Filled karşılığı yoksa (katalogda olmayan bir ad)
  /// pin ikonsuz çiziliyor; boş bir kutu çizmektense yalnız renkli damla.
  @visibleForTesting
  static String pinSvg(
    JobCategory category, {
    Brightness brightness = Brightness.light,
  }) {
    const half = _pinStroke / 2;
    const offset = 198 - _pinIconSize / 2;
    const scale = _pinIconSize / _reiconGrid;
    final iconPaths = (Reicon.filled[category.icon] ?? '').replaceAll(
      'currentColor',
      _hex(AppColors.onAccent),
    );
    return '<svg xmlns="http://www.w3.org/2000/svg" '
        'width="${396 + _pinStroke}" height="${568 + _pinStroke}" '
        'viewBox="${-half} ${-half} ${396 + _pinStroke} ${568 + _pinStroke}">'
        '<path d="$_pinPath" fill="${_hex(category.color)}" '
        'stroke="${_hex(AppMapStyle.pinRim(brightness))}" '
        'stroke-width="$_pinStroke" '
        'stroke-linejoin="round"/>'
        '<g transform="translate($offset $offset) scale($scale)">$iconPaths</g>'
        '</svg>';
  }

  static Future<BitmapDescriptor> _createIconFromSvg(
    JobCategory category,
    Brightness brightness,
  ) async {
    final PictureInfo pictureInfo = await vg.loadPicture(
      SvgStringLoader(pinSvg(category, brightness: brightness)),
      null,
    );

    final double pixelRatio = _pixelRatio;
    final double scale = _pinHeight * pixelRatio / pictureInfo.size.height;
    final double scaledWidth = pictureInfo.size.width * scale;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    canvas.scale(scale);
    canvas.drawPicture(pictureInfo.picture);

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      scaledWidth.round(),
      (_pinHeight * pixelRatio).round(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    pictureInfo.picture.dispose();
    image.dispose();

    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }

  /// SVG `#RRGGBB` bekler; saydamlık taşınmaz.
  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static void clearCache() {
    _iconCache.clear();
    _clusterIconCache.clear();
  }
}
