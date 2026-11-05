import 'package:flutter/widgets.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_scanner.dart';

/// Kamerası olmayan tarama yüzeyi (is-koala/koala#217).
///
/// `mobile_scanner` testte platform görünümü açamıyor; ekranlar yüzeyi
/// [BoardingCameraBuilder] ile aldığı için test bunu veriyor ve okunan kodu
/// ya da kamera hatasını elle gönderiyor.
class FakeBoardingCamera {
  BoardingCameraCallbacks? _callbacks;
  int builds = 0;

  /// Yüzey ağaçta mı (kamera açık mı).
  bool get isOpen => _callbacks != null;

  Widget build(BuildContext context, BoardingCameraCallbacks callbacks) {
    _callbacks = callbacks;
    builds++;
    return const SizedBox.expand(key: ValueKey('fake-boarding-camera'));
  }

  void scan(String raw) => _callbacks!.onCode(raw);

  void fail(BoardingCameraError error) => _callbacks!.onError(error);
}

/// İzin durumunu testin belirlediği sonda.
class FakeCameraPermissionProbe implements CameraPermissionProbe {
  FakeCameraPermissionProbe({this.permanentlyDenied = false});

  bool permanentlyDenied;
  int settingsOpened = 0;

  @override
  Future<bool> isPermanentlyDenied() async => permanentlyDenied;

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}
