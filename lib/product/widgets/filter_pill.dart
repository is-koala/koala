import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Süzgeç sheet'lerindeki seçenek hapı.
///
/// Keşfet'in süzgeç ve sıralama sheet'leri ile çubuktaki etkin süzgeç özeti
/// aynı çipi çiziyor; sayfaya gömülü özel bir metot olarak kalsaydı üç kopya
/// olurdu.
///
/// Adı `FilterChip` değil: Flutter'ın kendi `FilterChip`'i var ve aynı adı
/// taşıyan bir widget onu import eden ilk dosyada çakışır.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.onRemove,
    this.enabled = true,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  /// Verilirse çipin sağında bir çarpı çiziliyor: çubuktaki etkin süzgeç
  /// özetinde her çip kendi alanını temizliyor.
  final VoidCallback? onRemove;

  /// Kapalıyken soluk çiziliyor ve dokunmayı yutuyor — seçeneğin neden
  /// kullanılamadığını çipin yanındaki açıklama anlatıyor, çip sessizce
  /// kaybolmuyor.
  final bool enabled;

  /// Seçili çipin zemin opaklığı.
  static const double _selectedAlpha = 0.15;

  /// Kapalı çipin opaklığı.
  static const double _disabledOpacity = 0.4;

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final foreground = isSelected ? accent : context.textPrimary;

    final pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppPadding.primary,
        vertical: AppSizes.space,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? accent.withValues(alpha: _selectedAlpha)
            : context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(color: isSelected ? accent : context.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: foreground,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: AppSizes.spaceSmall),
            GestureDetector(
              onTap: enabled ? onRemove : null,
              child: Icon(
                Icons.close,
                size: AppSizes.iconSmall,
                color: foreground,
              ),
            ),
          ],
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : _disabledOpacity,
      child: GestureDetector(onTap: enabled ? onTap : null, child: pill),
    );
  }
}
