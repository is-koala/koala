import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Profildeki zaman çizelgesi satırı: solda nokta, sağda kart.
///
/// Hem deneyim hem eğitim bunu kullanıyor. Alan adları bu yüzden nötr:
/// deneyimde [subtitle] şirket, eğitimde üniversite oluyor.
class TimelineCard extends StatelessWidget {
  final String title;

  /// Başlığın altındaki vurgulu satır — deneyimde şirket, eğitimde okul.
  final String subtitle;

  /// [subtitle]'ın yanındaki ikon; çağıran alana göre veriyor.
  final IconData subtitleIcon;

  final String duration;
  final String description;
  final bool isLast;

  /// Düzenleme ve silme. `null` ise satırda menü çıkmıyor — başkasının
  /// profilinde kayıt yalnızca okunuyor.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TimelineCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.description,
    this.subtitleIcon = Icons.business,
    this.isLast = false,
    this.onEdit,
    this.onDelete,
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

  /// Düzenle / sil menüsü. İki eylem de verilmemişse kart salt okunur.
  Widget? _menu(BuildContext context) {
    if (onEdit == null && onDelete == null) return null;

    return PopupMenuButton<VoidCallback>(
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_vert,
        size: AppSizes.icon,
        color: context.textTertiary,
      ),
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        if (onEdit != null)
          PopupMenuItem(value: onEdit, child: const Text('Düzenle')),
        if (onDelete != null)
          PopupMenuItem(value: onDelete, child: const Text('Sil')),
      ],
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
          Row(
            children: [
              Expanded(child: Text(title, style: context.textTheme.titleSmall)),
              ?_menu(context),
            ],
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          _iconRow(
            context,
            icon: subtitleIcon,
            iconSize: AppSizes.iconSmall,
            text: subtitle,
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
          // Eğitim kaydında açıklama yok; boş satır kart yüksekliğini
          // gereksiz büyütmesin.
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            Text(description, style: context.textTheme.bodySmall),
          ],
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
