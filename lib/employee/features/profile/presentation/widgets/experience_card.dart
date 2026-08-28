import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Profildeki deneyim satırı: solda zaman çizelgesi noktası, sağda kart.
class ExperienceCard extends StatelessWidget {
  final String title;
  final String company;
  final String duration;
  final String description;
  final bool isLast;

  const ExperienceCard({
    super.key,
    required this.title,
    required this.company,
    required this.duration,
    required this.description,
    this.isLast = false,
  });

  /// Zaman çizelgesi sütununun genişliği; nokta ortalanacak kadar.
  static const double _timelineWidth = 24;
  static const double _dotSize = 14;
  static const double _lineWidth = 2;

  /// Noktaları birbirine bağlayan çizginin opaklığı; nokta öne çıksın diye
  /// çizgi soluk.
  static const double _lineAlpha = 0.3;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _timelineIndicator(context),
          const SizedBox(width: AppSizes.spaceMedium),
          Expanded(child: _cardContent(context)),
        ],
      ),
    );
  }

  Widget _timelineIndicator(BuildContext context) {
    return SizedBox(
      width: _timelineWidth,
      child: Column(
        children: [
          Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.accentColor,
            ),
          ),
          if (!isLast)
            Expanded(
              child: Container(
                width: _lineWidth,
                color: context.accentColor.withValues(alpha: _lineAlpha),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardContent(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : AppSizes.spaceMedium),
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textTheme.titleSmall),
          const SizedBox(height: AppSizes.spaceTiny),
          _iconRow(
            context,
            icon: Icons.business,
            iconSize: AppSizes.iconSmall,
            text: company,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: context.accentColor,
            ),
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          _iconRow(
            context,
            icon: Icons.calendar_today,
            iconSize: AppSizes.iconSmall,
            iconColor: context.textTertiary,
            text: duration,
            style: context.textTheme.labelMedium,
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(description, style: context.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _iconRow(
    BuildContext context, {
    required IconData icon,
    required double iconSize,
    required String text,
    TextStyle? style,
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: iconSize, color: iconColor ?? context.accentColor),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(text, style: style),
      ],
    );
  }
}
