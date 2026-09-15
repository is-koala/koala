import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Sheet'in döndürdüğü seçim: servis + durak.
typedef SeatChoice = ({String shuttleId, String stopId});

/// Bir yön için servis ve durak seçtiren sheet (is-koala/koala#197).
///
/// Servisler başlık, durakları satır: kullanıcı doğrudan bir durağa
/// dokunuyor, seçim servis+durak çiftidir. Dolu servisin durakları
/// dokunulamaz — sunucu zaten `409 TRANSPORT_SHUTTLE_FULL` diyecek, satırı
/// açık bırakmak kullanıcıyı o hataya göndermek olurdu. Kapasite
/// `seatsTaken`/`capacity` ile yazılıyor. Satırlar `Material` + `InkWell`;
/// `AppBottomSheet` içinde `ListTile` kullanılmıyor (AGENTS).
class SeatPickerSheet extends StatelessWidget {
  const SeatPickerSheet({
    super.key,
    required this.direction,
    required this.shuttles,
    this.selected,
  });

  final ShuttleDirection direction;
  final List<Shuttle> shuttles;

  /// Şu an seçili koltuk; satırı vurgulanıyor.
  final SeatAssignment? selected;

  /// Listenin kaplayabileceği en fazla yükseklik oranı; altındaki sayfa
  /// görünmeye devam etsin.
  static const double _maxHeightRatio = 0.7;

  /// Seçili satırın zemin opaklığı ve çerçevesi (`OptionSheet` ile aynı).
  static const double _selectedTintAlpha = 0.1;
  static const double _selectedBorderWidth = 2.0;

  static Future<SeatChoice?> show(
    BuildContext context, {
    required ShuttleDirection direction,
    required List<Shuttle> shuttles,
    SeatAssignment? selected,
  }) {
    return AppBottomSheet.show<SeatChoice>(
      context,
      builder: (_) => SeatPickerSheet(
        direction: direction,
        shuttles: shuttles,
        selected: selected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: '${direction.displayName} için koltuk seçin',
      child: Flexible(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: context.dynamicHeight(_maxHeightRatio),
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final shuttle in shuttles) ...[
                _shuttleHeader(context, shuttle),
                for (final stop in shuttle.stops)
                  _stopRow(context, shuttle, stop),
                const SizedBox(height: AppSizes.spaceSmall),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _shuttleHeader(BuildContext context, Shuttle shuttle) {
    final full = shuttle.isFull;
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSizes.spaceSmall,
        bottom: AppSizes.spaceSmall,
      ),
      child: Row(
        children: [
          AppIcon(
            AppIcons.bus,
            size: AppSizes.iconMedium,
            color: full ? context.textTertiary : context.accentColor,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Text(
              shuttle.name,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: full ? context.textTertiary : context.textPrimary,
              ),
            ),
          ),
          Text(
            full ? 'Dolu · ${shuttle.occupancyLabel}' : shuttle.occupancyLabel,
            key: ValueKey('seat-picker-occupancy-${shuttle.id}'),
            style: context.textTheme.labelMedium?.copyWith(
              color: full ? AppColors.danger : context.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopRow(BuildContext context, Shuttle shuttle, ShuttleStop stop) {
    final isSelected =
        selected?.shuttleId == shuttle.id && selected?.stopId == stop.id;
    final enabled = !shuttle.isFull || isSelected;
    final accent = context.accentColor;
    final address = stop.addressLine;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Material(
        color: isSelected
            ? accent.withValues(alpha: _selectedTintAlpha)
            : context.tileColor,
        borderRadius: AppRadius.innerCircular,
        child: InkWell(
          key: ValueKey('seat-picker-stop-${stop.id}'),
          borderRadius: AppRadius.innerCircular,
          onTap: enabled
              ? () => Navigator.pop<SeatChoice>(context, (
                  shuttleId: shuttle.id,
                  stopId: stop.id,
                ))
              : null,
          child: Container(
            padding: AppPadding.infoTile,
            decoration: BoxDecoration(
              borderRadius: AppRadius.innerCircular,
              border: isSelected
                  ? Border.all(color: accent, width: _selectedBorderWidth)
                  : null,
            ),
            child: Row(
              children: [
                AppIcon(
                  AppIcons.location,
                  size: AppSizes.iconMedium,
                  color: enabled ? accent : context.textTertiary,
                ),
                const SizedBox(width: AppSizes.space),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.displayName,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: enabled
                              ? context.textPrimary
                              : context.textTertiary,
                        ),
                      ),
                      if (address != null && address != stop.displayName)
                        Text(
                          address,
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.spaceSmall),
                Text(
                  stop.scheduledAt.toLocal().asShortTime,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled ? context.textPrimary : context.textTertiary,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: AppSizes.spaceSmall),
                  AppIcon(
                    AppIcons.check,
                    size: AppSizes.iconMedium,
                    color: accent,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
