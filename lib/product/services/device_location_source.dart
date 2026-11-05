import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Cihaz konumu isteğinin sonucu.
enum DeviceLocationStatus {
  /// Konum alındı; [DeviceLocationResult.position] dolu.
  located,

  /// Cihazın konum servisi kapalı.
  serviceDisabled,

  /// Kullanıcı izni reddetti ya da daha önce kalıcı olarak reddetmiş.
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

/// Cihaz konumuna açılan kapı.
///
/// İki yol var ve ayrımı ADR-0007 koyuyor: harita ekranı açılırken yalnız
/// **zaten verilmiş** izinle konum okunur ([currentIfGranted]); izin diyaloğu
/// yalnız kullanıcı "Konumumu kullan"a bastığında açılır ([requestCurrent]).
/// Gerçeği [GeolocatorLocationSource]; testler [FakeDeviceLocationSource]
/// enjekte eder.
abstract interface class DeviceLocationSource {
  /// İzin daha önce verilmişse konumu döner; izin **istemez**. İzin yoksa,
  /// servis kapalıysa ya da konum alınamazsa `null`.
  Future<LatLng?> currentIfGranted();

  /// [currentIfGranted] gibi izin istemez; ama anlık konum alınamazsa son
  /// bilinen konuma **yalnız [maxAge]'den gençse** düşer. Servis binişi
  /// (is-koala/koala#217) bunu kullanıyor: saatler önceki bir okuma
  /// "durağa uzak" bayrağını yanlış üretir, konumsuz biniş ise yalnız
  /// bayraksız kalır.
  Future<LatLng?> freshIfGranted({required Duration maxAge});

  /// Gerekiyorsa izni ister ve konumu döner.
  Future<DeviceLocationResult> requestCurrent();
}

/// `geolocator` üzerinden gerçek cihaz konumu.
class GeolocatorLocationSource implements DeviceLocationSource {
  const GeolocatorLocationSource();

  /// Anlık konum bu sürede gelmezse son bilinen konuma düşülüyor: adres
  /// pini için birkaç yüz metrelik eski bir okuma bile boş haritadan iyi.
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

  /// Son bilinen konum [maxAge]'den gençse onu, değilse `null` döner.
  /// Gelecekteki bir zaman damgası (saat kayması) da taze sayılmaz.
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

  /// Anlık konum; alınamazsa son bilinen konum; o da yoksa `null`.
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

/// Testte enjekte edilen kaynak; hangi yolun ne zaman çağrıldığını sayar.
@visibleForTesting
class FakeDeviceLocationSource implements DeviceLocationSource {
  FakeDeviceLocationSource({
    this.granted,
    this.requestResult = const DeviceLocationResult(
      DeviceLocationStatus.denied,
    ),
  });

  /// [currentIfGranted]'ın döndürdüğü konum; `null` "izin yok" demek.
  LatLng? granted;

  /// [freshIfGranted]'ın döndürdüğü konum; verilmezse [granted].
  LatLng? fresh;

  /// [freshIfGranted]'a verilen son yaş sınırı.
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
