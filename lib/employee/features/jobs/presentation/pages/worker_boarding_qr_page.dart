import 'dart:async';

import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/presentation/providers/boarding_qr_controller.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_qr_view.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_appbar.dart';

part 'worker_boarding_qr_pagemodel.dart';

/// İşçinin kişisel biniş QR'ı (is-koala/koala#217):
/// `GET /job-assignments/{id}/transport/qr?direction=…`.
///
/// İşveren ya da şoför bu QR'ı okutur. QR sunucunun `refreshAt`'inde
/// kendiliğinden yenilenir; ekran görüntüsü birkaç dakika sonra işe yaramaz.
/// `SHUTTLE_REMINDER_BOARDING` push'u doğrudan bu ekranı açar.
class WorkerBoardingQrPage extends StatefulWidget {
  const WorkerBoardingQrPage({
    super.key,
    required this.assignmentId,
    required this.direction,
    this.transportService,
  });

  final String assignmentId;
  final ShuttleDirection direction;
  final TransportService? transportService;

  /// Ekranın yönergesi.
  static const String instruction =
      'Servise binerken bu QR\'ı işverene ya da yetkiliye okutun. QR birkaç '
      'dakikada bir kendiliğinden yenilenir; ekran görüntüsü işe yaramaz.';

  /// Okunabilirlik ipucu.
  static const String brightnessTip =
      'Okutmayı kolaylaştırmak için ekran parlaklığını artırın.';

  @override
  State<WorkerBoardingQrPage> createState() => _WorkerBoardingQrPageState();
}

class _WorkerBoardingQrPageState extends WorkerBoardingQrPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MyAppbar(title: 'Biniş QR\'ım'),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: AppPadding.primaryAll,
          children: [
            Text(
              '${widget.direction.displayName} servisi',
              style: context.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              WorkerBoardingQrPage.instruction,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceLarge),
            _qrArea(context),
            const SizedBox(height: AppSizes.space),
            Text(
              WorkerBoardingQrPage.brightnessTip,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qrArea(BuildContext context) {
    final qr = controller.qr;
    final error = controller.error;
    if (qr == null) {
      if (error != null) return _errorPanel(context, error);
      return const Padding(
        padding: AppPadding.primaryAll,
        child: Center(
          child: CircularProgressIndicator(
            key: ValueKey('worker-boarding-qr-loading'),
          ),
        ),
      );
    }
    return Column(
      children: [
        BoardingQrView(qr: qr, expired: controller.isExpired),
        if (error != null) ...[
          const SizedBox(height: AppSizes.space),
          _strip(
            context,
            'QR yenilenemedi; bağlantı gelince yeniden denenecek.',
            key: const ValueKey('worker-boarding-qr-refresh-failed'),
          ),
        ],
      ],
    );
  }

  Widget _strip(BuildContext context, String text, {required Key key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        children: [
          const AppIcon(
            AppIcons.alert,
            size: AppSizes.iconSmall,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(child: Text(text, style: context.textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _errorPanel(BuildContext context, ApiException error) {
    return Container(
      key: const ValueKey('worker-boarding-qr-error'),
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        children: [
          AppIcon(
            AppIcons.qr,
            size: AppSizes.iconLarge,
            color: context.textTertiary,
          ),
          const SizedBox(height: AppSizes.space),
          Text(
            errorMessage(error),
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSizes.space),
          OutlinedButton(
            key: const ValueKey('worker-boarding-qr-retry'),
            onPressed: () => unawaited(controller.refresh()),
            style: context.accentOutlinedButtonStyle,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}
