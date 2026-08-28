import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
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
/// Materyal'in varsayılan snackbar'ı temanın dışında kalıyordu: köşeleri kare,
/// zemini gri, ekranın dibine yapışık. Burada kapsül biçimi butonlarla aynı
/// yarıçapı ([AppRadius.primary]) kullanıyor, zemin ve metin temadan okunuyor,
/// anlamı ise yalnızca soldaki ikonun rengi taşıyor — zeminin tamamını
/// boyamak metni iki temadan birinde okunmaz hâle getiriyordu.
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

  /// Kapsülün kenarlığı; açık temada zemin sayfadan yalnızca bir ton koyu
  /// olduğu için toast'ı ayıran şey bu ince çizgi.
  static const double _borderWidth = 1.0;

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

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              AppIcon(
                type.icon,
                size: AppSizes.iconMedium,
                color: type.colorOf(context),
                filled: true,
              ),
              const SizedBox(width: AppSizes.spaceSmall),
              Expanded(
                child: Text(
                  message,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: context.elevatedColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            // Butonlarla aynı yarıçap; yükseklik yarıçapın iki katını
            // aşmadığı için çizimde tam kapsüle iniyor.
            borderRadius: AppRadius.primaryCircular,
            side: BorderSide(color: context.dividerColor, width: _borderWidth),
          ),
          padding: AppPadding.toast,
          margin: AppPadding.toastMargin,
          duration: hasAction ? _actionDuration : _duration,
          action: hasAction
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: context.accentColor,
                  onPressed: onAction,
                )
              : null,
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
