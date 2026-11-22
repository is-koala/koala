import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Biniş QR'ının çizimi (#217): iki temada beyaz üstüne siyah, sunucunun
/// `uri`'si aynen basılır. [maxSide]'a kadar büyür: karşı telefon 30-40 cm'den
/// okusun, sayfa kaymasın.
class BoardingQrView extends StatelessWidget {
  const BoardingQrView({
    super.key,
    required this.qr,
    this.expired = false,
    this.maxSide = defaultMaxSide,
  });

  final BoardingQr qr;

  /// Süresi doldu: soluklaşır ve açıklama yazılır ki geçersiz kod okutulmasın.
  final bool expired;
  final double maxSide;

  static const double defaultMaxSide = 320;

  static const double _expiredOpacity = 0.12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxSide;
        final side = math.min(available, maxSide);

        return Center(
          child: Container(
            key: const ValueKey('boarding-qr'),
            width: side,
            height: side,
            padding: AppPadding.card,
            decoration: const BoxDecoration(
              color: AppColors.qrBackground,
              borderRadius: AppRadius.innerCircular,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: expired ? _expiredOpacity : 1.0,
                  child: QrImageView(
                    data: qr.uri,
                    padding: AppPadding.zero,
                    backgroundColor: AppColors.qrBackground,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    semanticsLabel: 'Biniş QR kodu',
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.qrForeground,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.qrForeground,
                    ),
                  ),
                ),
                if (expired)
                  Center(
                    child: Column(
                      key: const ValueKey('boarding-qr-expired'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppIcon(
                          AppIcons.refresh,
                          size: AppSizes.iconLarge,
                          color: AppColors.qrForeground,
                        ),
                        const SizedBox(height: AppSizes.spaceSmall),
                        Text(
                          'QR\'ın süresi doldu; yenileniyor.',
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: AppColors.qrForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
