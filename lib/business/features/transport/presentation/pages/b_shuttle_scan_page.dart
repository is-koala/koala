import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_result_panel.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_scanner.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/device_location_source.dart';
import 'package:koala/product/widgets/my_appbar.dart';

part 'b_shuttle_scan_pagemodel.dart';

/// İşveren çalışanın kişisel QR'ını okutur (is-koala/koala#217):
/// `POST /seat-assignments/{seatAssignmentId}/boardings` token ile.
///
/// Dolu bir servisi tek telefondan taramak için kamera açık kalır: her
/// okutmanın sonucu altta yazılır ve sıradaki çalışan okutulabilir. Koltuk
/// kimliği token'ın kendisinde; ad, servisin biniş listesinden bulunur.
class BShuttleScanPage extends StatefulWidget {
  const BShuttleScanPage({
    super.key,
    required this.shuttleId,
    this.shuttleName,
    this.transportService,
    this.locationSource,
    this.cameraBuilder,
    this.permissionProbe,
    this.appScheme,
  });

  final String shuttleId;
  final String? shuttleName;
  final TransportService? transportService;
  final DeviceLocationSource? locationSource;
  final BoardingCameraBuilder? cameraBuilder;
  final CameraPermissionProbe? permissionProbe;
  final String? appScheme;

  static const String instruction =
      'Çalışanın uygulamasındaki biniş QR\'ını çerçevenin içine getirin.';

  static const String unavailableHint =
      'Bunun yerine biniş listesinden çalışanları elle işaretleyebilir ya da '
      'servis QR\'ını çalışanlara okutabilirsiniz.';

  /// Konum bu sürede gelmezse okutma konumsuz gider.
  static const Duration locationTimeout = Duration(seconds: 3);

  /// Çalışan QR'ını kaydeder ve sonucun ekrandaki hâlini döndürür. Konum
  /// yalnız izin zaten verilmişse eklenir; diyalog açılmaz.
  ///
  /// [shuttleId] ve [names] (bu servisin koltuk → ad listesi) verilirse
  /// okutulan koltuk bu serviste değilse kayıt yine yapılır ama sonuç
  /// uyarı olarak yazılır: işçi yanlış servise binmiş olabilir.
  static Future<BoardingResultPanel> record({
    required TransportService service,
    required DeviceLocationSource location,
    required BoardingToken token,
    required DateTime capturedAt,
    String? shuttleId,
    Map<String, String> names = const {},
  }) async {
    try {
      final position = await _currentPosition(location);
      final event = await service.markSeatBoarding(
        token.subjectId,
        clientEventId: newBoardingClientEventId(),
        token: token.value,
        capturedAt: capturedAt,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
      final seatId = event.seatAssignmentId ?? token.subjectId;
      final name = names[seatId];
      final eventShuttle = event.shuttleId?.toLowerCase();
      final otherShuttle =
          shuttleId != null &&
          ((names.isNotEmpty && name == null) ||
              (eventShuttle != null &&
                  eventShuttle != shuttleId.toLowerCase()));
      if (otherShuttle) {
        return BoardingResultPanel(
          tone: BoardingResultTone.warning,
          message: name == null
              ? 'Biniş kaydedildi, ama bu çalışan bu servisin listesinde yok.'
              : '$name bindi, ama koltuğu başka bir serviste.',
          detail:
              'Çalışanın doğru servise bindiğinden emin olun; gerekirse '
              'koltuğunu iş detayından değiştirin.',
        );
      }
      return BoardingResultPanel(
        tone: BoardingResultTone.success,
        message: name == null ? 'Biniş kaydedildi.' : '$name bindi.',
        detail: event.replayed
            ? 'Bu kalkış için biniş zaten kayıtlıydı.'
            : _flagLine(event.flags),
      );
    } on ApiException catch (error) {
      return BoardingResultPanel(
        tone: BoardingResultTone.failure,
        message: BoardingFailure.classify(
          error,
        ).message(BoardingActor.employer, serverMessage: error.message),
      );
    }
  }

  /// Telefon kamerasıyla okutulan `{şema}://board?t=…` bağlantısı
  /// (`/boarding-link`) işveren oturumunda buradan gönderilir.
  static Future<BoardingResultPanel> submitFromLink(
    BuildContext context,
    BoardingToken token,
    DateTime capturedAt,
  ) => record(
    service: TransportService(),
    location: const GeolocatorLocationSource(),
    token: token,
    capturedAt: capturedAt,
  );

  static String? _flagLine(Set<BoardingFlag> flags) =>
      flags.isEmpty ? null : flags.map((flag) => flag.displayName).join(' · ');

  static Future<LatLng?> _currentPosition(DeviceLocationSource location) async {
    try {
      return await location
          .freshIfGranted(maxAge: boardingLocationMaxAge)
          .timeout(locationTimeout, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  @override
  State<BShuttleScanPage> createState() => _BShuttleScanPageState();
}

class _BShuttleScanPageState extends BShuttleScanPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MyAppbar(title: 'Çalışan QR\'ı okut'),
      body: SafeArea(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: BoardingScannerView(
            actor: BoardingActor.employer,
            acceptedKind: BoardingTokenKind.worker,
            instruction: BShuttleScanPage.instruction,
            unavailableHint: BShuttleScanPage.unavailableHint,
            busy: busy,
            status: lastResult,
            onToken: onToken,
            cameraBuilder: widget.cameraBuilder,
            permissionProbe: widget.permissionProbe,
            appScheme: widget.appScheme,
          ),
        ),
      ),
    );
  }
}
