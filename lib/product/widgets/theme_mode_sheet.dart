import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:provider/provider.dart';

/// Ayarlarda gösterilen tema adı.
extension ThemeModeLabel on ThemeMode {
  String get label => switch (this) {
    ThemeMode.system => 'Sistem',
    ThemeMode.light => 'Açık',
    ThemeMode.dark => 'Koyu',
  };

  String get description => switch (this) {
    ThemeMode.system => 'Cihazının görünüm ayarını takip eder',
    ThemeMode.light => 'Her zaman açık tema',
    ThemeMode.dark => 'Her zaman koyu tema',
  };

  AppIconData get icon => switch (this) {
    ThemeMode.system => AppIcons.mobile,
    ThemeMode.light => AppIcons.sun,
    ThemeMode.dark => AppIcons.moon,
  };
}

/// Görünüm tercihini seçtiren bottom sheet.
///
/// Seçim anında uygulanıyor; ayrı bir "kaydet" adımı yok — kullanıcı temayı
/// sheet açıkken görüp karar verebilsin diye.
class ThemeModeSheet extends StatelessWidget {
  const ThemeModeSheet({super.key});

  /// Seçili satırın zemin opaklığı.
  static const double _selectedTintAlpha = 0.1;

  static Future<void> show(BuildContext context) {
    return AppBottomSheet.show(
      context,
      builder: (context) => const ThemeModeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // watch: seçim yapılınca sheet'in kendisi de yeni temaya boyanıyor.
    final provider = context.watch<ThemeProvider>();

    return AppBottomSheet(
      title: 'Görünüm',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in ThemeMode.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
              child: _option(
                context,
                mode: mode,
                isSelected: provider.themeMode == mode,
                onTap: () => provider.setThemeMode(mode),
              ),
            ),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required ThemeMode mode,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final accent = context.accentColor;

    return Material(
      color: isSelected
          ? accent.withValues(alpha: _selectedTintAlpha)
          : context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: InkWell(
        borderRadius: AppRadius.innerCircular,
        onTap: onTap,
        child: Container(
          padding: AppPadding.tileTall,
          decoration: BoxDecoration(
            borderRadius: AppRadius.innerCircular,
            border: Border.all(
              color: isSelected ? accent : context.dividerColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              AppIcon(
                mode.icon,
                color: isSelected ? accent : context.textSecondary,
                size: AppSizes.iconMedium,
              ),
              const SizedBox(width: AppSizes.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? accent : context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.smallGap),
                    Text(
                      mode.description,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? accent.withValues(alpha: 0.7)
                            : context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                AppIcon(
                  AppIcons.tick,
                  color: accent,
                  size: AppSizes.iconMedium,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
