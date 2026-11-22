import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_shadows.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Toast'un anlamı: hangi ikon ve hangi vurgu rengiyle çıkacağını belirler.
enum AppToastType {
  /// Tamamlanan işlem: başvuru gönderildi, ilan yayınlandı.
  success,

  /// Başarısız işlem, eksik alan, sunucu hatası.
  error,

  /// Nötr bilgilendirme; ne olumlu ne olumsuz.
  info,
}

/// Uygulamanın tek bildirim kutusu.
///
/// Materyal'in snackbar'ı yalnız konum ve süre için kullanılıyor; görünüşü
/// kendi kartımız ([_ToastCard]) çiziyor. Snackbar'ın kendi zemini, kenarlığı
/// ve sert gölgesi gri bir hap gibi duruyordu (2026-11-22): kart artık
/// uygulamanın kartlarıyla aynı yarıçapta, sayfanın zemin renginde ve
/// yumuşak bir gölgeyle ayrılıyor. Anlamı yalnızca soldaki ikonun rengi
/// taşıyor — zeminin tamamını boyamak metni iki temadan birinde okunmaz
/// hâle getiriyordu.
///
/// ```dart
/// AppToast.success(context, 'Başvurun gönderildi');
/// AppToast.error(context, 'Başvuru gönderilemedi.');
/// AppToast.info(context, 'İlan kaldırıldı', actionLabel: 'Geri Al',
///     onAction: () => provider.toggleSave(job));
/// ```
///
/// Yüzen (`floating`) davranış kasıtlı: `Scaffold`, yüzen snackbar'ı
/// `bottomNavigationBar`'ın **üstüne** yerleştiriyor, böylece toast iki
/// uygulamanın navbar'ının da altında kalmıyor.
abstract final class AppToast {
  /// Ekranda kalma süresi. Materyal'in dört saniyesinden kısa: mesajlar tek
  /// satırlık, uzun durunca navbar'ın üstünde göze batıyor.
  static const Duration _duration = Duration(seconds: 3);

  /// Eylemli toast daha uzun durur; kullanıcının "Geri Al"a basacak zamanı
  /// olmalı.
  static const Duration _actionDuration = Duration(seconds: 5);

  /// Tamamlanan bir işlemi bildirir.
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

  /// Başarısız bir işlemi ya da eksik girdiyi bildirir.
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

  /// Nötr bilgilendirme yapar.
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

  /// Toast'u gösterir.
  ///
  /// Sıradaki toast beklemez: art arda gelen iki mesajda kullanıcı ikincisini
  /// görmek ister, birincisinin süresini doldurmasını değil.
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
          // Zemin, kenar ve gölge kartın; snackbar yalnız yeri ve süreyi
          // veriyor.
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

/// Toast'un görünen kartı.
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
    // Koyu temada yükselti daha açık bir yüzeyle anlatılıyor; açık temada
    // kart sayfanın beyazında kalıyor ve gölgeyle ayrılıyor.
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

/// [AppToastType]'ın görünümü: ikon ve vurgu rengi.
///
/// Sunum tarafı burada duruyor ki tipin kendisi anlamdan ibaret kalsın.
extension _AppToastStyle on AppToastType {
  AppIconData get icon => switch (this) {
    AppToastType.success => AppIcons.checkCircle,
    AppToastType.error => AppIcons.alert,
    AppToastType.info => AppIcons.info,
  };

  /// Vurgu rengi. Başarı marka yeşilini kullanıyor: kullanıcı onayı
  /// uygulamanın her yerinde bu renkten tanıyor.
  Color colorOf(BuildContext context) => switch (this) {
    AppToastType.success => context.accentColor,
    AppToastType.error => AppColors.danger,
    AppToastType.info => AppColors.info,
  };
}
