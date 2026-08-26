import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:flutter_svg/flutter_svg.dart';

class JobMarkerGenerator {
  static final Map<JobCategory, BitmapDescriptor> _iconCache = {};

  static Future<Set<Marker>> generateMarkers({
    required List<Job> jobs,
    required void Function(Job job) onMarkerTap,
  }) async {
    final Set<Marker> markers = {};

    for (final job in jobs) {
      final marker = await _createMarker(job, onMarkerTap);
      markers.add(marker);
    }

    return markers;
  }

  static Future<Marker> _createMarker(
    Job job,
    void Function(Job job) onMarkerTap,
  ) async {
    final BitmapDescriptor icon = await _getOrCreateIcon(job.category);

    return Marker(
      markerId: MarkerId(job.id),
      position: LatLng(job.latitude, job.longitude),
      icon: icon,
      onTap: () => onMarkerTap(job),
      anchor: const Offset(0.5, 1.0), // Pin'in alt noktası konumu göstersin
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
