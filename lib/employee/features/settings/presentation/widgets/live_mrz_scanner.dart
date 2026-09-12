import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_region.dart';
import 'package:koala/employee/features/settings/models/mrz_scan_session.dart';
import 'package:koala/employee/features/settings/services/mrz_camera_session.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Canlı kamera, MRZ kadrajı ve kullanıcı yönlendirmesinin tek yüzeyi.
class LiveMrzScanner extends StatefulWidget {
  const LiveMrzScanner({
    super.key,
    required this.camera,
    required this.onCaptured,
    required this.onFailure,
    required this.onManualEntry,
    this.successHold = const Duration(milliseconds: 450),
    this.haptic,
  });

  final MrzCameraSession camera;
  final ValueChanged<MrzKey> onCaptured;
  final ValueChanged<ChipReadFailure> onFailure;
  final VoidCallback onManualEntry;

  /// Yeşil durumun ekranda okunmasına fırsat veren kısa bekleme.
  final Duration successHold;

  /// Testte platform titreşimini cihaz sınırında değiştirebilmek için.
  final Future<void> Function()? haptic;

  @override
  State<LiveMrzScanner> createState() => _LiveMrzScannerState();
}

class _LiveMrzScannerState extends State<LiveMrzScanner>
    with WidgetsBindingObserver {
  bool _started = false;
  bool _completed = false;
  late AppLifecycleState _lifecycleState;
  final MrzScanSession _scan = MrzScanSession(requiredStableFrames: 3);
  late final StreamSubscription<MrzFrameObservation> _observations;
  Future<void>? _lifecycleSync;
  AppLifecycleState? _syncedLifecycleState;
  MrzScanState _state = const MrzScanState(guidance: MrzScanGuidance.preparing);

  @override
  void initState() {
    super.initState();
    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _observations = widget.camera.observations.listen(
      _observe,
      onError: (Object error, StackTrace _) {
        _fail(
          error is ChipReadException
              ? error.reason
              : ChipReadFailure.mrzUnreadable,
        );
      },
    );
    unawaited(_start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (!_started || _completed) return;
    _requestLifecycleSync();
  }

  /// Hızlı `inactive → paused → resumed` zincirini tek seri kuyruğa indirger.
  void _requestLifecycleSync() {
    if (_lifecycleSync != null) return;
    final operation = _drainLifecycleChanges();
    _lifecycleSync = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_lifecycleSync, operation)) _lifecycleSync = null;
        if (mounted &&
            _started &&
            !_completed &&
            _syncedLifecycleState != _lifecycleState) {
          _requestLifecycleSync();
        }
      }),
    );
  }

  Future<void> _drainLifecycleChanges() async {
    while (mounted && _started && !_completed) {
      final target = _lifecycleState;
      if (_syncedLifecycleState == target) return;
      try {
        if (target == AppLifecycleState.resumed) {
          await widget.camera.resume();
        } else {
          await widget.camera.pause();
        }
      } on ChipReadException catch (error) {
        _fail(error.reason);
        return;
      } on Object {
        _fail(ChipReadFailure.unknown);
        return;
      }
      _syncedLifecycleState = target;
      if (target == _lifecycleState) return;
    }
  }

  void _fail(ChipReadFailure reason) {
    if (!mounted || _completed) return;
    _completed = true;
    widget.onFailure(reason);
  }

  void _observe(MrzFrameObservation observation) {
    if (_completed || !mounted) return;
    final next = _scan.observe(observation);
    setState(() => _state = next);

    final key = next.key;
    if (key == null) return;
    _completed = true;
    unawaited(_finish(key));
  }

  Future<void> _finish(MrzKey key) async {
    // Başarı kesinleştiği anda yeni ham kare almayı kesiyoruz; yeşil durum
    // ekranda kalırken kamera gereksiz kişisel veri üretmesin.
    try {
      final lifecycleSync = _lifecycleSync;
      if (lifecycleSync != null) await lifecycleSync;
      await widget.camera.pause();
    } on Object {
      // Akış zaten tamamlandı; kameranın kapanış hatası sonucu değiştirmez.
    }

    try {
      await (widget.haptic ?? HapticFeedback.mediumImpact)();
    } on Object {
      // Titreşim erişilebilirlik desteğidir, çip anahtarını bloke etmez.
    }
    await Future<void>.delayed(widget.successHold);
    if (mounted) widget.onCaptured(key);
  }

  Future<void> _start() async {
    try {
      await widget.camera.start();
      if (mounted) {
        _syncedLifecycleState = AppLifecycleState.resumed;
        setState(() {
          _started = true;
          _state = const MrzScanState(guidance: MrzScanGuidance.moveCloser);
        });
        if (_lifecycleState != AppLifecycleState.resumed) {
          _requestLifecycleSync();
        }
      }
    } on ChipReadException catch (error) {
      _fail(error.reason);
    } on Object {
      _fail(ChipReadFailure.unknown);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_observations.cancel());
    unawaited(widget.camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _state.isReady ? AppColors.success : AppColors.warning;

    return ColoredBox(
      color: AppColors.onLightSurface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraLayer(context, statusColor),
          Positioned(
            left: AppSizes.spaceMedium,
            right: AppSizes.spaceMedium,
            bottom: AppSizes.spaceLarge,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    label: _state.message,
                    child: Container(
                      width: double.infinity,
                      padding: AppPadding.primaryAll,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: AppRadius.secondaryCircular,
                      ),
                      child: Text(
                        _state.message,
                        textAlign: TextAlign.center,
                        style: context.textTheme.titleSmall?.copyWith(
                          color: AppColors.onLightSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceSmall),
                  TextButton(
                    onPressed: widget.onManualEntry,
                    child: const Text('Bilgileri Elle Gir'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraLayer(BuildContext context, Color statusColor) {
    if (!_started) {
      return const Center(child: CircularProgressIndicator());
    }
    final previewSize = widget.camera.previewSize;
    if (previewSize == null || previewSize.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final surface = Size(constraints.maxWidth, constraints.maxHeight);
        final fitted = applyBoxFit(BoxFit.contain, previewSize, surface);
        final previewRect = Alignment.center.inscribe(
          fitted.destination,
          Offset.zero & surface,
        );
        final scanRect = MrzScanRegion.pixelRegion(
          previewRect.size,
        ).shift(previewRect.topLeft);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fromRect(
              rect: previewRect,
              child: widget.camera.buildPreview(),
            ),
            Positioned.fromRect(
              rect: scanRect,
              child: Semantics(
                container: true,
                excludeSemantics: true,
                label:
                    'TCKK arka yüzündeki üç satırlık MRZ alanı için '
                    'tarama çerçevesi',
                child: AnimatedContainer(
                  key: const ValueKey('mrz-scan-frame'),
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    border: Border.all(color: statusColor, width: 3),
                    borderRadius: AppRadius.innerCircular,
                  ),
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: AppPadding.chip,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: AppRadius.smallCircular,
                    ),
                    child: Text(
                      'MRZ • 3 SATIR',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: AppColors.onLightSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
