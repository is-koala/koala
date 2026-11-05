import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';

part 'b_shuttle_boardings_pagemodel.dart';

/// Servisin biniş listesi (is-koala/koala#217): `GET /shuttles/{id}/boardings`.
///
/// Durak ve kalkış saatine göre gruplanmış koltuklar; her satırda bindi /
/// binmedi / bekleniyor ve sunucunun bayrakları. İşveren elle BİNDİ ya da
/// BİNMEDİ işaretleyebilir (`POST /seat-assignments/{id}/boardings`, token
/// yok), servisin QR'ını açabilir ya da çalışanın QR'ını okutabilir.
/// `SHUTTLE_NOTICE_NOT_BOARDED` push'u bu ekranı açar.
class BShuttleBoardingsPage extends StatefulWidget {
  const BShuttleBoardingsPage({
    super.key,
    required this.shuttleId,
    this.shuttleName,
    this.transportService,
  });

  final String shuttleId;
  final String? shuttleName;
  final TransportService? transportService;

  @override
  State<BShuttleBoardingsPage> createState() => _BShuttleBoardingsPageState();
}

class _BShuttleBoardingsPageState extends BShuttleBoardingsPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: title),
      body: RefreshIndicator(onRefresh: load, child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final rows = this.rows;
    if (rows == null) {
      if (errorMessage != null) return _error(context, errorMessage!);
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('b-boardings-loading')),
      );
    }

    final groups = groupedRows;
    return ListView(
      padding: AppPadding.primaryAll,
      children: [
        _actions(context),
        const SizedBox(height: AppSizes.spaceLarge),
        if (rows.isEmpty)
          Text(
            'Bu serviste koltuk seçmiş çalışan yok.',
            key: const ValueKey('b-boardings-empty'),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
        for (final group in groups) ...[
          _groupHeader(context, group),
          const SizedBox(height: AppSizes.spaceSmall),
          for (final row in group.rows) ...[
            _row(context, row),
            const SizedBox(height: AppSizes.spaceSmall),
          ],
          const SizedBox(height: AppSizes.space),
        ],
        const SizedBox(height: AppSizes.navBarClearance),
      ],
    );
  }

  Widget _error(BuildContext context, String message) {
    return EmptyState(
      icon: AppIcons.alert,
      title: 'Biniş listesi yüklenemedi',
      description: message,
      action: OutlinedButton(
        key: const ValueKey('b-boardings-retry'),
        onPressed: () => unawaited(load()),
        style: context.accentOutlinedButtonStyle,
        child: const Text('Tekrar Dene'),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            context,
            key: const ValueKey('b-boardings-show-qr'),
            icon: AppIcons.qr,
            label: 'Servis QR\'ı',
            onPressed: openShuttleQr,
          ),
        ),
        const SizedBox(width: AppSizes.spaceSmall),
        Expanded(
          child: _actionButton(
            context,
            key: const ValueKey('b-boardings-scan'),
            icon: AppIcons.scan,
            label: 'Çalışan QR\'ı okut',
            onPressed: openScanner,
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required Key key,
    required AppIconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: AppSizes.actionButtonHeight,
      child: OutlinedButton.icon(
        key: key,
        onPressed: onPressed,
        icon: AppIcon(
          icon,
          size: AppSizes.iconSmall,
          color: context.accentColor,
        ),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: context.accentOutlinedButtonStyle,
      ),
    );
  }

  Widget _groupHeader(BuildContext context, BoardingStopGroup group) {
    return Row(
      children: [
        AppIcon(
          AppIcons.location,
          size: AppSizes.iconSmall,
          color: context.textTertiary,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Expanded(
          child: Text(
            '${group.stopName} · ${group.scheduledAt.toLocal().asShortTime}',
            style: context.textTheme.titleSmall,
          ),
        ),
        Text(
          '${group.boardedCount}/${group.rows.length} bindi',
          style: context.textTheme.labelMedium?.copyWith(
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, ShuttleBoardingRow row) {
    final busy = busySeatId == row.seatAssignmentId;
    final event = row.event;
    final flags = event?.flags ?? const <BoardingFlag>{};
    final (Color color, String label) = row.boarded
        ? (
            AppColors.success,
            'Bindi · ${event?.occurredAt.toLocal().asShortTime ?? ''}',
          )
        : row.isNoShow
        ? (AppColors.danger, 'Binmedi')
        : (context.textSecondary, 'Bekleniyor');

    return Container(
      key: ValueKey('b-boarding-row-${row.seatAssignmentId}'),
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.displayName,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                label,
                key: ValueKey('b-boarding-status-${row.seatAssignmentId}'),
                style: context.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (flags.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              flags.map((flag) => flag.displayName).join(' · '),
              style: context.textTheme.labelSmall?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
          const SizedBox(height: AppSizes.spaceSmall),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (busy)
                const SizedBox.square(
                  dimension: AppSizes.iconMedium,
                  child: CircularProgressIndicator(strokeWidth: _spinnerStroke),
                )
              else ...[
                if (!row.boarded && !row.isNoShow)
                  TextButton(
                    key: ValueKey('b-boarding-no-show-${row.seatAssignmentId}'),
                    onPressed: busySeatId == null
                        ? () => unawaited(mark(row, BoardingKind.noShow))
                        : null,
                    child: const Text('Binmedi'),
                  ),
                if (!row.boarded)
                  TextButton(
                    key: ValueKey('b-boarding-boarded-${row.seatAssignmentId}'),
                    onPressed: busySeatId == null
                        ? () => unawaited(mark(row, BoardingKind.boarded))
                        : null,
                    child: const Text('Bindi'),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Bekleme halkasının kalınlığı.
  static const double _spinnerStroke = 2;
}
