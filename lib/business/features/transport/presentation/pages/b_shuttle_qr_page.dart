import 'dart:async';

import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/presentation/providers/boarding_qr_controller.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_qr_view.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/my_appbar.dart';

part 'b_shuttle_qr_pagemodel.dart';

/// Servisin biniş QR'ı (is-koala/koala#217): `GET /shuttles/{id}/qr`.
///
/// Varsayılan dönen QR: `refreshAt`'te kendiliğinden yenilenir, servisteki
/// tablet ya da telefonda açık tutulur. "Basılı QR" süresizdir, kâğıda
/// basılır; onunla yapılan biniş `STATIC_QR` bayrağı taşır. "QR'ı yenile"
/// (`POST …/qr/rotate`) anahtarı değiştirir: basılı QR dahil eski servis
/// QR'ları ve çalışanların bu servisteki QR'ları anında geçersiz olur —
/// onaylı bir işlem.
class BShuttleQrPage extends StatefulWidget {
  const BShuttleQrPage({
    super.key,
    required this.shuttleId,
    this.shuttleName,
    this.transportService,
  });

  final String shuttleId;
  final String? shuttleName;
  final TransportService? transportService;

  static const String rotatingNote =
      'Çalışanlar servise binerken bu QR\'ı kendi uygulamalarıyla okutur. QR '
      'birkaç dakikada bir kendiliğinden yenilenir; ekranı açık tutun.';

  static const String staticNote =
      'Bu QR süresizdir; kâğıda basıp serviste asabilirsiniz. Bu QR\'la '
      'yapılan binişler "Basılı QR" olarak işaretlenir. Kaybolursa ya da '
      'paylaşılırsa aşağıdan yenileyin.';

  static const String rotateMessage =
      'Basılı QR dahil bu servisin önceki bütün QR\'ları ve çalışanların bu '
      'servisteki kişisel QR\'ları hemen geçersiz olur. Basılı QR\'ı yeniden '
      'yazdırmanız gerekir.';

  @override
  State<BShuttleQrPage> createState() => _BShuttleQrPageState();
}

class _BShuttleQrPageState extends BShuttleQrPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: title),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: AppPadding.primaryAll,
          children: [
            _modeSelector(context),
            const SizedBox(height: AppSizes.space),
            Text(
              isStatic
                  ? BShuttleQrPage.staticNote
                  : BShuttleQrPage.rotatingNote,
              key: const ValueKey('b-shuttle-qr-note'),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceLarge),
            _qrArea(context),
            const SizedBox(height: AppSizes.spaceLarge),
            SizedBox(
              height: AppSizes.actionButtonHeight,
              child: OutlinedButton.icon(
                key: const ValueKey('b-shuttle-qr-rotate'),
                onPressed: rotating ? null : () => unawaited(rotate()),
                icon: AppIcon(
                  AppIcons.refresh,
                  size: AppSizes.iconSmall,
                  color: AppColors.danger,
                ),
                label: const Text('QR\'ı yenile (eskisini iptal et)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.smallCircular,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.navBarClearance),
          ],
        ),
      ),
    );
  }

  Widget _modeSelector(BuildContext context) {
    return SegmentedButton<bool>(
      key: const ValueKey('b-shuttle-qr-mode'),
      segments: const [
        ButtonSegment(value: false, label: Text('Dönen QR')),
        ButtonSegment(value: true, label: Text('Basılı QR')),
      ],
      selected: {isStatic},
      showSelectedIcon: false,
      onSelectionChanged: (selection) =>
          unawaited(selectMode(isStatic: selection.first)),
    );
  }

  Widget _qrArea(BuildContext context) {
    final qr = controller.qr;
    final error = controller.error;
    if (qr == null) {
      if (error != null) {
        return Column(
          key: const ValueKey('b-shuttle-qr-error'),
          children: [
            Text(
              errorMessage(error),
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSizes.space),
            OutlinedButton(
              onPressed: () => unawaited(controller.refresh()),
              style: context.accentOutlinedButtonStyle,
              child: const Text('Tekrar Dene'),
            ),
          ],
        );
      }
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('b-shuttle-qr-loading')),
      );
    }
    return Column(
      children: [
        BoardingQrView(qr: qr, expired: controller.isExpired),
        if (error != null) ...[
          const SizedBox(height: AppSizes.space),
          Text(
            'QR yenilenemedi; yeniden deneniyor.',
            key: const ValueKey('b-shuttle-qr-refresh-failed'),
            style: context.textTheme.bodySmall?.copyWith(
              color: AppColors.warning,
            ),
          ),
        ],
      ],
    );
  }
}
