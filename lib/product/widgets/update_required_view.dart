import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_info.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sürüm kapısı kapanınca uygulamanın üstünü kapatan ekran. Kapatma yolu yok:
/// sunucu bu sürümün her isteğini reddediyor.
class UpdateRequiredView extends StatelessWidget {
  const UpdateRequiredView({
    super.key,
    required this.message,
    this.iosAppStoreId = AppInfo.iosAppStoreId,
    this.androidPackageId = AppInfo.androidPackageId,
  });

  final String message;

  /// Testler kimliğin dolu ve boş hâllerini buradan geçiyor.
  final String iosAppStoreId;

  final String androidPackageId;

  static const double _iconBox = 96;

  /// Mağaza adresi bilinmiyorken kullanıcıya bırakılan yol.
  static const String _noStoreGuidance =
      'Bu cihaz için mağaza bağlantımız henüz yok. Uygulamayı kurduğun '
      'yerden güncelleyebilir, sorun sürerse ${AppInfo.supportEmail} adresine '
      'yazabilirsin.';

  /// Platformun mağaza adresi; kimliği boşsa `null`. Diğer platforma yedek yol
  /// **yok**: iPhone kullanıcısını Google Play'e göndermek düğmesizlikten kötü.
  @visibleForTesting
  static Uri? storeUriFor({
    required TargetPlatform platform,
    required String iosAppStoreId,
    required String androidPackageId,
  }) => switch (platform) {
    TargetPlatform.iOS when iosAppStoreId.isNotEmpty => Uri.parse(
      'https://apps.apple.com/app/id$iosAppStoreId',
    ),
    TargetPlatform.android when androidPackageId.isNotEmpty => Uri.parse(
      'https://play.google.com/store/apps/details?id=$androidPackageId',
    ),
    _ => null,
  };

  /// Düğmenin varlığı ile adresi tek değer; ayrı bayrak olsa ayrışabilirdi.
  Uri? get _storeUri => storeUriFor(
    platform: defaultTargetPlatform,
    iosAppStoreId: iosAppStoreId,
    androidPackageId: androidPackageId,
  );

  Future<void> _openStore(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final storeUri = _storeUri;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppPadding.primaryAll,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _iconBox,
                  height: _iconBox,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(
                      alpha: AppColors.surfaceTintAlpha,
                    ),
                    borderRadius: AppRadius.secondaryCircular,
                  ),
                  child: AppIcon(
                    AppIcons.download,
                    size: AppSizes.iconLarge,
                    color: context.accentColor,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceLarge),
                Text(
                  'Güncelleme gerekli',
                  style: context.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.spaceSmall),
                Text(
                  message,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (storeUri != null) ...[
                  const SizedBox(height: AppSizes.spaceXLarge),
                  MyButton(
                    title: 'Mağazayı Aç',
                    onPressed: () => _openStore(storeUri),
                  ),
                ] else ...[
                  const SizedBox(height: AppSizes.spaceMedium),
                  Text(
                    _noStoreGuidance,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.textTertiary,
                    ),
                    textAlign: TextAlign.center,
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
