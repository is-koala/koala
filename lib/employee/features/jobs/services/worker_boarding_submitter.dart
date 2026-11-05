import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/jobs/presentation/providers/boarding_queue_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/services/device_location_source.dart';

/// İşçinin servis QR okutmasını kuyruğa veren tek yol (is-koala/koala#217).
///
/// İş detayındaki tarama ekranı da, telefon kamerasıyla açılan
/// `{şema}://board?t=…` bağlantısı da buradan geçiyor: oturum sahibinin
/// kuyruğu başlatılır, konum **yalnız izin zaten verilmişse** ve en fazla
/// [boardingLocationMaxAge] yaşındaysa eklenir (izin diyaloğu açılmaz;
/// ADR-0007 ile aynı ilke) ve okutma
/// [BoardingQueueProvider.submit]'e gider.
class WorkerBoardingSubmitter {
  WorkerBoardingSubmitter({
    required this.queue,
    required this.users,
    DeviceLocationSource? location,
  }) : _location = location ?? const GeolocatorLocationSource();

  final BoardingQueueProvider queue;
  final UserProvider users;
  final DeviceLocationSource _location;

  /// Konum bu sürede gelmezse okutma konumsuz gider: biniş kapı değil,
  /// konum yalnız `FAR_FROM_STOP` bayrağı için.
  static const Duration locationTimeout = Duration(seconds: 3);

  /// [capturedAt] okutma anı; konum beklenirken geçen süre biniş anına
  /// eklenmesin diye çağıran verir.
  Future<BoardingSubmission> submit({
    required BoardingToken token,
    required DateTime capturedAt,
    String? assignmentId,
    ShuttleDirection? direction,
  }) async {
    if (users.user == null) await users.load(silent: true);
    final userId = users.user?.id;
    if (userId == null) {
      throw StateError('Oturum sahibi okunamadı.');
    }
    if (queue.activeUserId != userId) await queue.startForUser(userId);

    final position = await _currentPosition();
    return queue.submit(
      token: token,
      capturedAt: capturedAt,
      latitude: position?.latitude,
      longitude: position?.longitude,
      assignmentId: assignmentId,
      direction: direction,
    );
  }

  Future<LatLng?> _currentPosition() async {
    try {
      return await _location
          .freshIfGranted(maxAge: boardingLocationMaxAge)
          .timeout(locationTimeout, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }
}
