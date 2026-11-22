import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/models/scanner_failure_window.dart';
import 'package:koala/product/network/api_config.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

enum BoardingCameraError {
  permissionDenied,

  unsupported,

  /// QR çözücü çalışmıyor: Play Services'ı olmayan cihaz ya da model inmedi.
  scannerUnavailable,

  failed,
}

class BoardingCameraCallbacks {
  const BoardingCameraCallbacks({required this.onCode, required this.onError});

  /// Ham metin; ayrıştırmak sayfanın işi.
  final ValueChanged<String> onCode;
  final ValueChanged<BoardingCameraError> onError;
}

/// Testler kamerasız sahte yüzey verir.
typedef BoardingCameraBuilder = Widget Function(
  BuildContext context,
  BoardingCameraCallbacks callbacks,
);

abstract interface class CameraPermissionProbe {
  /// Sistem diyaloğu bir daha açılmayacak; kullanıcı ayarlara gitmeli.
  Future<bool> isPermanentlyDenied();

  Future<bool> openSettings();
}

class PermissionHandlerCameraProbe implements CameraPermissionProbe {
  const PermissionHandlerCameraProbe();

  @override
  Future<bool> isPermanentlyDenied() async {
    try {
      final status = await Permission.camera.status;
      // iOS ilk retten, Android iki retten sonra `permanentlyDenied` veriyor.
      return status.isPermanentlyDenied || status.isRestricted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }
}

/// Biniş QR'ı okutan ekranların ortak gövdesi (#217). Kamera yalnız bu ağaç
/// varken açık ve arka planda durur. Yalnız [acceptedKind] türündeki token
/// [onToken]'a gider; ham içerik yazdırılmaz.
class BoardingScannerView extends StatefulWidget {
  const BoardingScannerView({
    super.key,
    required this.actor,
    required this.acceptedKind,
    required this.onToken,
    required this.instruction,
    this.busy = false,
    this.status,
    this.unavailableHint,
    this.cameraBuilder,
    this.permissionProbe,
    this.appScheme,
    this.now,
  });

  final BoardingActor actor;
  final BoardingTokenKind acceptedKind;

  /// Kabul edilen token ve okutma anı (UTC).
  final void Function(BoardingToken token, DateTime capturedAt) onToken;

  final String instruction;

  final bool busy;

  final Widget? status;

  final String? unavailableHint;

  final BoardingCameraBuilder? cameraBuilder;
  final CameraPermissionProbe? permissionProbe;

  final String? appScheme;
  final DateTime Function()? now;

  /// Aynı QR'ı önünde tutan kullanıcı ikinci istek göndermesin.
  static const Duration repeatWindow = Duration(seconds: 30);

  static const Duration hintDuration = Duration(seconds: 4);

  static String wrongKindMessage(BoardingTokenKind accepted) =>
      accepted == BoardingTokenKind.shuttle
      ? 'Bu bir çalışan QR\'ı. Bindiğiniz servisteki QR\'ı okutun.'
      : 'Bu bir servis QR\'ı. Çalışanın uygulamasındaki kişisel QR\'ı '
            'okutun.';

  static const String notBoardingQrMessage = 'Bu bir Koala biniş QR\'ı değil.';

  @override
  State<BoardingScannerView> createState() => _BoardingScannerViewState();
}

class _BoardingScannerViewState extends State<BoardingScannerView>
    with WidgetsBindingObserver {
  static const double _spinnerStroke = 2;

  BoardingCameraError? _error;
  bool _permanentlyDenied = false;
  int _cameraGeneration = 0;
  String? _hint;
  Timer? _hintTimer;
  String? _lastCode;
  DateTime? _lastCodeAt;

  /// Ayarlardan dönüşte kamera yeniden denenir; hemen denemek yine
  /// reddedilirdi.
  bool _awaitingSettings = false;

  CameraPermissionProbe get _probe =>
      widget.permissionProbe ?? const PermissionHandlerCameraProbe();

  DateTime _now() => (widget.now ?? DateTime.now)().toUtc();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingSettings) {
      _awaitingSettings = false;
      if (mounted) _retry();
    }
  }

  void _onCode(String raw) {
    if (!mounted || widget.busy) return;
    final now = _now();
    final lastAt = _lastCodeAt;
    if (raw == _lastCode &&
        lastAt != null &&
        now.difference(lastAt) < BoardingScannerView.repeatWindow) {
      return;
    }
    _lastCode = raw;
    _lastCodeAt = now;

    final token = BoardingToken.parse(
      raw,
      appScheme: widget.appScheme ?? ApiConfig.appUrlScheme,
    );
    if (token == null) {
      _showHint(BoardingScannerView.notBoardingQrMessage);
      return;
    }
    if (token.kind != widget.acceptedKind) {
      _showHint(BoardingScannerView.wrongKindMessage(widget.acceptedKind));
      return;
    }
    _clearHint();
    widget.onToken(token, now);
  }

  void _showHint(String message) {
    _hintTimer?.cancel();
    setState(() => _hint = message);
    _hintTimer = Timer(BoardingScannerView.hintDuration, () {
      if (mounted) setState(() => _hint = null);
    });
  }

  void _clearHint() {
    _hintTimer?.cancel();
    if (_hint != null) setState(() => _hint = null);
  }

  Future<void> _onError(BoardingCameraError error) async {
    if (!mounted || _error != null) return;
    var permanent = false;
    if (error == BoardingCameraError.permissionDenied) {
      permanent = await _probe.isPermanentlyDenied();
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      _permanentlyDenied = permanent;
    });
  }

  void _retry() {
    setState(() {
      _error = null;
      _permanentlyDenied = false;
      _cameraGeneration++;
    });
  }

  Future<void> _openSettings() async {
    _awaitingSettings = true;
    final opened = await _probe.openSettings();
    if (!opened) _awaitingSettings = false;
  }

  @override
  Widget build(BuildContext context) {
    final BoardingCameraBuilder builder =
        widget.cameraBuilder ??
        (context, callbacks) => MobileScannerCamera(callbacks: callbacks);
    final error = _error;

    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadius.innerCircular,
            child: error != null
                ? _errorPanel(context, error)
                : KeyedSubtree(
                    key: ValueKey('boarding-camera-$_cameraGeneration'),
                    child: builder(
                      context,
                      BoardingCameraCallbacks(
                        onCode: _onCode,
                        onError: _onError,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSizes.space),
        _footer(context),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final hint = _hint;
    if (hint != null) {
      return _note(
        context,
        hint,
        icon: AppIcons.alert,
        color: AppColors.warning,
        key: const ValueKey('boarding-scanner-hint'),
      );
    }
    if (widget.busy) {
      return Row(
        key: const ValueKey('boarding-scanner-busy'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: AppSizes.iconMedium,
            child: CircularProgressIndicator(
              strokeWidth: _spinnerStroke,
              color: context.accentColor,
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Text('Gönderiliyor…', style: context.textTheme.bodyMedium),
        ],
      );
    }
    final status = widget.status;
    if (status != null) return status;
    return Text(
      widget.instruction,
      key: const ValueKey('boarding-scanner-instruction'),
      textAlign: TextAlign.center,
      style: context.textTheme.bodyMedium?.copyWith(
        color: context.textSecondary,
      ),
    );
  }

  Widget _note(
    BuildContext context,
    String text, {
    required String icon,
    required Color color,
    Key? key,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: AppSizes.iconSmall, color: color),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(child: Text(text, style: context.textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _errorPanel(BuildContext context, BoardingCameraError error) {
    final (title, body) = switch (error) {
      BoardingCameraError.permissionDenied when _permanentlyDenied => (
        'Kamera izni kapalı',
        'QR okutmak için Ayarlar\'dan Koala\'ya kamera izni verin.',
      ),
      BoardingCameraError.permissionDenied => (
        'Kamera izni verilmedi',
        'QR okutabilmek için kameraya izin vermeniz gerekiyor.',
      ),
      BoardingCameraError.unsupported => (
        'Kamera bulunamadı',
        'Bu cihazda QR okutmak için kullanılabilecek bir kamera yok.',
      ),
      BoardingCameraError.scannerUnavailable => (
        'QR okuyucu hazırlanamadı',
        'QR okuyucu bu cihazda Google Play Hizmetleri\'ni gerektiriyor; ilk '
            'kullanımda internet bağlantısı da gerekebilir.',
      ),
      BoardingCameraError.failed => (
        'Kamera açılamadı',
        'Kamera şu an kullanılamıyor. Yeniden deneyin.',
      ),
    };
    final hint = widget.unavailableHint;
    final showHint =
        hint != null &&
        (error == BoardingCameraError.scannerUnavailable ||
            error == BoardingCameraError.unsupported ||
            _permanentlyDenied);

    return Container(
      key: ValueKey('boarding-camera-error-${error.name}'),
      width: double.infinity,
      color: context.tileColor,
      padding: AppPadding.primaryAll,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcons.camera,
                size: AppSizes.iconLarge,
                color: context.textTertiary,
              ),
              const SizedBox(height: AppSizes.space),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSizes.spaceSmall),
              Text(
                body,
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                ),
              ),
              if (showHint) ...[
                const SizedBox(height: AppSizes.spaceSmall),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.spaceMedium),
              if (error == BoardingCameraError.permissionDenied &&
                  _permanentlyDenied)
                OutlinedButton(
                  key: const ValueKey('boarding-camera-settings'),
                  onPressed: _openSettings,
                  style: context.accentOutlinedButtonStyle,
                  child: const Text('Ayarları Aç'),
                )
              else if (error != BoardingCameraError.unsupported)
                OutlinedButton(
                  key: const ValueKey('boarding-camera-retry'),
                  onPressed: _retry,
                  style: context.accentOutlinedButtonStyle,
                  child: const Text('Tekrar Dene'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gerçek kamera: yalnız QR, ortada kare pencere, fener.
class MobileScannerCamera extends StatefulWidget {
  const MobileScannerCamera({super.key, required this.callbacks});

  final BoardingCameraCallbacks callbacks;

  /// QR'ı ortalamaya zorlar, kenardaki kodları dışarıda bırakır.
  static const double windowFraction = 0.72;

  @override
  State<MobileScannerCamera> createState() => _MobileScannerCameraState();
}

class _MobileScannerCameraState extends State<MobileScannerCamera>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  final ScannerFailureWindow _failures = ScannerFailureWindow();
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  /// Denetleyiciyi biz verdiğimiz için yaşam döngüsünü `mobile_scanner`
  /// izlemiyor. İzin yokken başlatmak yeni diyalog açardı.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_quietly(_controller.start()));
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        unawaited(_quietly(_controller.stop()));
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Geçişte zararsız `MobileScannerException`'ları yutar.
  static Future<void> _quietly(Future<void> operation) async {
    try {
      await operation;
    } on MobileScannerException {
      // Bilerek yutuluyor.
    }
  }

  void _report(BoardingCameraError error) {
    if (_reported) return;
    _reported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.callbacks.onError(error);
    });
  }

  void _onDetect(BarcodeCapture capture) {
    _failures.reset();
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        widget.callbacks.onCode(raw);
        return;
      }
    }
  }

  void _onDetectError(Object error, StackTrace stackTrace) {
    if (_failures.record(DateTime.now())) {
      _report(BoardingCameraError.scannerUnavailable);
    }
  }

  BoardingCameraError _mapError(MobileScannerException error) =>
      switch (error.errorCode) {
        MobileScannerErrorCode.permissionDenied =>
          BoardingCameraError.permissionDenied,
        MobileScannerErrorCode.unsupported => BoardingCameraError.unsupported,
        _ => BoardingCameraError.failed,
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final side =
            math.min(size.width, size.height) *
            MobileScannerCamera.windowFraction;
        final window = Rect.fromCenter(
          center: size.center(Offset.zero),
          width: side,
          height: side,
        );

        return ColoredBox(
          color: AppColors.scrim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                scanWindow: window,
                onDetect: _onDetect,
                onDetectError: _onDetectError,
                errorBuilder: (context, error) {
                  _report(_mapError(error));
                  return const ColoredBox(color: AppColors.scrim);
                },
              ),
              ScanWindowOverlay(
                controller: _controller,
                scanWindow: window,
                borderColor: AppColors.onAccent,
                borderRadius: AppRadius.innerCircular,
                borderWidth: AppSizes.spaceTiny,
                color: AppColors.scrim.withValues(
                  alpha: AppColors.scannerScrimAlpha,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSizes.spaceMedium,
                child: Center(child: _torchButton()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _torchButton() {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: _controller,
      builder: (context, state, _) {
        final torch = state.torchState;
        if (!state.isInitialized || torch == TorchState.unavailable) {
          return const SizedBox.shrink();
        }
        final on = torch == TorchState.on;
        return IconButton.filled(
          key: const ValueKey('boarding-camera-torch'),
          tooltip: on ? 'Feneri kapat' : 'Feneri aç',
          onPressed: () => unawaited(_controller.toggleTorch()),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.scrim.withValues(
              alpha: AppColors.scannerScrimAlpha,
            ),
          ),
          icon: AppIcon(
            on ? AppIcons.flashlightOn : AppIcons.flashlight,
            color: AppColors.onAccent,
          ),
        );
      },
    );
  }
}
