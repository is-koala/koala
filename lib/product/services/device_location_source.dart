import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum DeviceLocationStatus {
  located,

  serviceDisabled,

  denied,

  /// İzin var ama konum alınamadı (zaman aşımı, platform hatası).
  unavailable,
}

class DeviceLocationResult {
  const DeviceLocationResult(this.status, [this.position]);

  const DeviceLocationResult.located(LatLng this.position)
    : status = DeviceLocationStatus.located;

  final DeviceLocationStatus status;
  final LatLng? position;
}

/// Cihaz konumu (ADR-0007): ekran açılırken yalnız **zaten verilmiş** izinle
/// okunur ([currentIfGranted]); izin diyaloğu yalnız "Konumumu kullan"da
/// ([requestCurrent]).
abstract interface class DeviceLocationSource {
  /// İzin istemez; izin yoksa ya da konum alınamazsa `null`.
  Future<LatLng?> currentIfGranted();

  /// İzin istemez; anlık konum yoksa son bilinene yalnız [maxAge]'den gençse
  /// düşer. Biniş (#217) için: eski okuma yanlış "durağa uzak" bayrağı üretir.
  Future<LatLng?> freshIfGranted({required Duration maxAge});

  Future<DeviceLocationResult> requestCurrent();
}

class GeolocatorLocationSource implements DeviceLocationSource {
  const GeolocatorLocationSource();

  /// Adres pini için birkaç yüz metre eski okuma boş haritadan iyi.
  static const Duration _fixTimeout = Duration(seconds: 8);

  @override
  Future<LatLng?> currentIfGranted() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      if (!_isGranted(await Geolocator.checkPermission())) return null;
      return await _read();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<LatLng?> freshIfGranted({required Duration maxAge}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      if (!_isGranted(await Geolocator.checkPermission())) return null;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: _fixTimeout,
          ),
        );
        return LatLng(position.latitude, position.longitude);
      } catch (_) {
        return freshFallback(
          await Geolocator.getLastKnownPosition(),
          now: DateTime.now(),
          maxAge: maxAge,
        );
      }
    } catch (_) {
      return null;
    }
  }

  /// Gelecekteki zaman damgası (saat kayması) taze sayılmaz.
  @visibleForTesting
  static LatLng? freshFallback(
    Position? last, {
    required DateTime now,
    required Duration maxAge,
  }) {
    if (last == null) return null;
    final age = now.toUtc().difference(last.timestamp.toUtc());
    if (age.isNegative || age > maxAge) return null;
    return LatLng(last.latitude, last.longitude);
  }

  @override
  Future<DeviceLocationResult> requestCurrent() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DeviceLocationResult(DeviceLocationStatus.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!_isGranted(permission)) {
        return const DeviceLocationResult(DeviceLocationStatus.denied);
      }

      final position = await _read();
      return position == null
          ? const DeviceLocationResult(DeviceLocationStatus.unavailable)
          : DeviceLocationResult.located(position);
    } catch (_) {
      return const DeviceLocationResult(DeviceLocationStatus.unavailable);
    }
  }

  static bool _isGranted(LocationPermission permission) =>
      permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;

  static Future<LatLng?> _read() async {
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _fixTimeout,
        ),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }
    return position == null
        ? null
        : LatLng(position.latitude, position.longitude);
  }
}

@visibleForTesting
class FakeDeviceLocationSource implements DeviceLocationSource {
  FakeDeviceLocationSource({
    this.granted,
    this.requestResult = const DeviceLocationResult(
      DeviceLocationStatus.denied,
    ),
  });

  /// `null` "izin yok" demek.
  LatLng? granted;

  /// Verilmezse [granted].
  LatLng? fresh;

  Duration? lastMaxAge;

  DeviceLocationResult requestResult;

  int currentIfGrantedCalls = 0;
  int requestCalls = 0;

  @override
  Future<LatLng?> currentIfGranted() async {
    currentIfGrantedCalls++;
    return granted;
  }

  @override
  Future<LatLng?> freshIfGranted({required Duration maxAge}) async {
    lastMaxAge = maxAge;
    return fresh ?? granted;
  }

  @override
  Future<DeviceLocationResult> requestCurrent() async {
    requestCalls++;
    return requestResult;
  }
}
