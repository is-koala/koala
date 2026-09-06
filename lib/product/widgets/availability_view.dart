import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/models/availability.dart';
import 'package:koala/product/models/availability_day.dart';
import 'package:koala/product/models/availability_exception.dart';
import 'package:koala/product/models/availability_slot.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Kullanıcının müsaitliğini değiştirmeden gösteren ortak görünüm.
///
/// İş arayan kendi profilinde, işveren de aday profilinde aynı sözleşmeyi
/// okuduğu için iki uygulamanın ortak `product/` katmanında yaşar.
class AvailabilityView extends StatelessWidget {
  const AvailabilityView({
    super.key,
    required this.availability,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.onEdit,
  });

  final Availability? availability;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Müsaitlik', style: context.textTheme.titleMedium),
            ),
            if (onEdit != null)
              IconButton(
                tooltip: 'Müsaitliği düzenle',
                onPressed: onEdit,
                icon: AppIcon(
                  AppIcons.edit,
                  size: AppSizes.iconMedium,
                  color: context.accentColor,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.spaceSmall),
        if (isLoading && availability == null)
          _loading(context)
        else if (errorMessage != null && availability == null)
          _error(context)
        else if (availability == null || availability!.isEmpty)
          _empty(context)
        else
          _content(context, availability!),
      ],
    );
  }

  Widget _loading(BuildContext context) {
    return _panel(
      context,
      Row(
        children: [
          SizedBox(
            width: AppSizes.iconMedium,
            height: AppSizes.iconMedium,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.accentColor,
            ),
          ),
          const SizedBox(width: AppSizes.space),
          Text(
            'Müsaitlik yükleniyor...',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _error(BuildContext context) {
    return _panel(
      context,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            AppIcons.alert,
            size: AppSizes.iconSmall,
            color: context.textTertiary,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage!,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Tekrar dene'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return _panel(
      context,
      Text(
        'Müsaitlik bilgisi paylaşılmamış.',
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.textTertiary,
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Availability value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (value.slots.isNotEmpty) _weeklyPanel(context, value.slots),
        if (value.slots.isNotEmpty && value.exceptions.isNotEmpty)
          const SizedBox(height: AppSizes.spaceMedium),
        if (value.exceptions.isNotEmpty) ...[
          Text(
            'Tarih İstisnaları',
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          _panel(
            context,
            Column(
              children: value.exceptions
                  .map((exception) => _exceptionRow(context, exception))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _weeklyPanel(BuildContext context, List<AvailabilitySlot> slots) {
    final visibleDays = AvailabilityDay.values.where(
      (day) => slots.any((slot) => slot.day == day),
    );

    return _panel(
      context,
      Column(
        children: visibleDays.map((day) {
          final daySlots = slots.where((slot) => slot.day == day).toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppSizes.navBar,
                  child: Text(
                    daySlots.first.dayLabel,
                    style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.spaceSmall),
                Expanded(
                  child: Wrap(
                    spacing: AppSizes.spaceSmall,
                    runSpacing: AppSizes.spaceTiny,
                    children: daySlots
                        .map((slot) => _timeBadge(context, slot.timeLabel))
                        .toList(),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _timeBadge(BuildContext context, String label) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.accentColor.withValues(
          alpha: AppColors.surfaceTintAlpha,
        ),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Padding(
        padding: AppPadding.badge,
        child: Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.accentColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _exceptionRow(BuildContext context, AvailabilityException exception) {
    final statusColor = exception.available
        ? AppColors.successStrong
        : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            AppIcons.calendar,
            size: AppSizes.iconSmall,
            color: statusColor,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      exception.date.asShortDate,
                      style: context.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceSmall),
                    Text(
                      exception.available ? 'Çalışabilirim' : 'Çalışamam',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (exception.note?.isNotEmpty == true) ...[
                  const SizedBox(height: AppSizes.spaceTiny),
                  Text(
                    exception.note!,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, Widget child) {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: child,
    );
  }
}
