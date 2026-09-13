import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/product/services/device_location_source.dart';

/// `geolocator`'ın platform kanalı; `LocationPermission` sıralaması:
/// 0 denied, 1 deniedForever, 2 whileInUse, 3 always.
const _channel = MethodChannel('flutter.baseflow.com/geolocator');
const _denied = 0;
const _deniedForever = 1;
const _whileInUse = 2;

class _Device {
  _Device({
    this.serviceEnabled = true,
    this.permission = _denied,
    this.permissionAfterRequest = _whileInUse,
    this.lastKnown,
    this.currentPositionFails = false,
  });

  bool serviceEnabled;
  int permission;
  int permissionAfterRequest;
  Map<String, double>? lastKnown;
  bool currentPositionFails;

  final List<String> calls = [];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'isLocationServiceEnabled':
              return serviceEnabled;
            case 'checkPermission':
              return permission;
            case 'requestPermission':
              permission = permissionAfterRequest;
              return permission;
            case 'getCurrentPosition':
              if (currentPositionFails) {
                throw PlatformException(code: 'LOCATION_UNAVAILABLE');
              }
              return const {'latitude': 41.04, 'longitude': 29.0};
            case 'getLastKnownPosition':
              return lastKnown;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = GeolocatorLocationSource();

  group('currentIfGranted', () {
    test('izin yoksa izin istemez ve null döner', () async {
      final device = _Device()..install();

      expect(await source.currentIfGranted(), isNull);
      expect(device.calls, isNot(contains('requestPermission')));
      expect(device.calls, isNot(contains('getCurrentPosition')));
    });

    test('izin varsa konumu okur, yine izin istemez', () async {
      final device = _Device(permission: _whileInUse)..install();

      expect(await source.currentIfGranted(), const LatLng(41.04, 29.0));
      expect(device.calls, isNot(contains('requestPermission')));
    });

    test('anlık konum alınamazsa son bilinen konuma düşer', () async {
      final device = _Device(
        permission: _whileInUse,
        currentPositionFails: true,
        lastKnown: const {'latitude': 41.01, 'longitude': 28.98},
      )..install();

      expect(await source.currentIfGranted(), const LatLng(41.01, 28.98));
      expect(device.calls, contains('getLastKnownPosition'));
    });

    test('konum servisi kapalıysa izne bile bakmaz', () async {
      final device = _Device(serviceEnabled: false, permission: _whileInUse)
        ..install();

      expect(await source.currentIfGranted(), isNull);
      expect(device.calls, ['isLocationServiceEnabled']);
    });
  });

  group('requestCurrent', () {
    test('izin yoksa ister; verilirse konumu döner', () async {
      final device = _Device()..install();

      final result = await source.requestCurrent();

      expect(device.calls, contains('requestPermission'));
      expect(result.status, DeviceLocationStatus.located);
      expect(result.position, const LatLng(41.04, 29.0));
    });

    test('kullanıcı reddederse denied döner, konum okunmaz', () async {
      final device = _Device(permissionAfterRequest: _denied)..install();

      final result = await source.requestCurrent();

      expect(result.status, DeviceLocationStatus.denied);
      expect(device.calls, isNot(contains('getCurrentPosition')));
    });

    test('kalıcı ret için diyalog açmaz, doğrudan denied döner', () async {
      final device = _Device(permission: _deniedForever)..install();

      final result = await source.requestCurrent();

      expect(result.status, DeviceLocationStatus.denied);
      expect(device.calls, isNot(contains('requestPermission')));
    });

    test('servis kapalıysa serviceDisabled döner', () async {
      _Device(serviceEnabled: false).install();

      final result = await source.requestCurrent();

      expect(result.status, DeviceLocationStatus.serviceDisabled);
    });

    test('izin var ama konum yoksa unavailable döner', () async {
      _Device(
        permission: _whileInUse,
        currentPositionFails: true,
        lastKnown: null,
      ).install();

      final result = await source.requestCurrent();

      expect(result.status, DeviceLocationStatus.unavailable);
      expect(result.position, isNull);
    });
  });
}
