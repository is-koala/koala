import 'package:flutter/widgets.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_session.dart';

/// Kamera eklentisini canlı MRZ ekranından ayıran cihaz sınırı.
abstract interface class MrzCameraSession {
  Stream<MrzFrameObservation> get observations;

  /// Dik önizleme alanı; UI kadrajını kamera pikseliyle aynı geometriye bağlar.
  Size? get previewSize;

  Widget buildPreview();

  Future<void> start();

  Future<void> pause();

  Future<void> resume();

  Future<void> dispose();
}
