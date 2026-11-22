import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_shadows.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

enum AppToastType { success, error, info }

/// Uygulamanın tek bildirim kutusu.
///
/// Snackbar yalnız konum ve süre için; görünüşü [_ToastCard] çiziyor.
/// Snackbar'ın kendi zemini ve gölgesi gri bir hap gibi duruyor. Anlamı yalnız
/// ikonun rengi taşıyor; zemini boyamak metni bir temada okunmaz yapar. Yüzen
/// davranış kasıtlı: `Scaffold` onu navbar'ın üstüne koyuyor.
///
/// ```dart
/// AppToast.info(context, 'İlan kaldırıldı', actionLabel: 'Geri Al',
///     onAction: () => provider.toggleSave(job));
/// ```
abstract final class AppToast {
  /// Materyal'in 4 saniyesinden kısa: mesajlar tek satırlık.
  static const Duration _duration = Duration(seconds: 3);

  /// Kullanıcının "Geri Al"a basacak zamanı olmalı.
  static const Duration _actionDuration = Duration(seconds: 5);

  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message,
      type: AppToastType.success,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message,
      type: AppToastType.error,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message,
      type: AppToastType.info,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Toast'u gösterir. Sıradaki toast beklemez: kullanıcı ikinci mesajı görmek
  /// ister.
  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final hasAction = actionLabel != null && onAction != null;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          behavior: SnackBarBehavior.floating,
          margin: AppPadding.toastMargin,
          duration: hasAction ? _actionDuration : _duration,
          content: _ToastCard(
            message: message,
            type: type,
            actionLabel: hasAction ? actionLabel : null,
            onAction: hasAction
                ? () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  }
                : null,
          ),
        ),
      );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.message,
    required this.type,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    // Koyu temada yükselti açık yüzeyle, açık temada gölgeyle anlatılıyor.
    final surface = context.isDarkTheme
        ? context.elevatedColor
        : context.backgroundColor;

    return Container(
      key: const ValueKey('app-toast'),
      padding: AppPadding.toast,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(color: context.dividerColor),
        boxShadow: AppShadows.overlay,
      ),
      child: Row(
        children: [
          AppIcon(
            type.icon,
            size: AppSizes.iconMedium,
            color: type.colorOf(context),
            filled: true,
          ),
          const SizedBox(width: AppSizes.space),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: AppSizes.spaceSmall),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: context.accentColor,
                textStyle: context.textTheme.labelLarge,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spaceSmall,
                  vertical: AppSizes.spaceTiny,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}

extension _AppToastStyle on AppToastType {
  AppIconData get icon => switch (this) {
    AppToastType.success => AppIcons.checkCircle,
    AppToastType.error => AppIcons.alert,
    AppToastType.info => AppIcons.info,
  };

  /// Başarı marka yeşili: kullanıcı onayı her yerde bu renkten tanıyor.
  Color colorOf(BuildContext context) => switch (this) {
    AppToastType.success => context.accentColor,
    AppToastType.error => AppColors.danger,
    AppToastType.info => AppColors.info,
  };
}
