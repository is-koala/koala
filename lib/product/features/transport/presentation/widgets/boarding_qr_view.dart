import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Biniş QR'ının çizimi (is-koala/koala#217).
///
/// İki temada da beyaz zemin üstüne siyah ([AppColors.qrBackground] /
/// [AppColors.qrForeground]); koyu temada ters renkli QR'ı birçok okuyucu
/// tanımıyor. QR'a sunucunun verdiği `uri` aynen basılır; istemci içerik
/// üretmez. Boyut ekrana göre büyür ama [maxSide]'ı geçmez — karşı telefon
/// 30-40 cm'den okuyabilsin diye büyük, sayfa kaydırılmasın diye sınırlı.
class BoardingQrView extends StatelessWidget {
  const BoardingQrView({
    super.key,
    required this.qr,
    this.expired = false,
    this.maxSide = defaultMaxSide,
  });

  final BoardingQr qr;

  /// Sunucunun kabul süresi doldu: QR soluklaşır ve üstüne açıklama yazılır,
  /// geçersiz bir kodun okutulup "süresi dolmuş" hatası alınmasın.
  final bool expired;
  final double maxSide;

  /// Varsayılan en büyük kenar.
  static const double defaultMaxSide = 320;

  /// Süresi dolmuş QR'ın opaklığı.
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
