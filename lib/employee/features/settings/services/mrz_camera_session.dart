import 'package:flutter/widgets.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_session.dart';

/// Kamera eklentisini canlı MRZ ekranından ayıran cihaz sınırı.
abstract interface class MrzCameraSession {
  Stream<MrzFrameObservation> get observations;

  Widget buildPreview();

  Future<void> start();

  Future<void> pause();

  Future<void> resume();

  Future<void> dispose();
}
