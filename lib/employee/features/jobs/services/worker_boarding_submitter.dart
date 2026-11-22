import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/jobs/presentation/providers/boarding_queue_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/services/device_location_source.dart';

/// İşçinin servis QR okutmasını kuyruğa veren tek yol (#217). Konum yalnız izin
/// zaten varsa ve [boardingLocationMaxAge]'den gençse eklenir.
class WorkerBoardingSubmitter {
  WorkerBoardingSubmitter({
    required this.queue,
    required this.users,
    DeviceLocationSource? location,
  }) : _location = location ?? const GeolocatorLocationSource();

  final BoardingQueueProvider queue;
  final UserProvider users;
  final DeviceLocationSource _location;

  /// Biniş kapı değil; konum yalnız `FAR_FROM_STOP` bayrağı için.
  static const Duration locationTimeout = Duration(seconds: 3);

  /// Konum beklenirken geçen süre eklenmesin diye çağıran verir.
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
