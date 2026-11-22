import 'package:flutter/widgets.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_session.dart';

abstract interface class MrzCameraSession {
  Stream<MrzFrameObservation> get observations;

  Size? get previewSize;

  Widget buildPreview();

  Future<void> start();

  Future<void> pause();

  Future<void> resume();

  Future<void> dispose();
}
