import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

/// Sürüm kapısı kapandığında uygulamanın üstünü kapatan ekran.
///
/// Kapatma yolu **yok**: sunucu bu sürümden gelen her isteği geri
/// çeviriyor, arkadaki ekranlara dönmek kullanıcıyı boş bir uygulamada
/// dolaştırmaktan başka işe yaramaz.
class UpdateRequiredView extends StatelessWidget {
  const UpdateRequiredView({
    super.key,
    required this.message,
    this.iosAppStoreId = AppInfo.iosAppStoreId,
    this.androidPackageId = AppInfo.androidPackageId,
  });

  /// Sunucunun gönderdiği açıklama.
  final String message;

  /// App Store'daki sayısal uygulama kimliği. Varsayılanı `AppInfo`'dan
  /// geliyor; testler kimliğin dolu ve boş hâllerini buradan geçiyor.
  final String iosAppStoreId;

  /// Play Store paket adı. Varsayılanı `AppInfo`'dan geliyor.
  final String androidPackageId;

  /// İkonu taşıyan kutunun kenar uzunluğu.
  static const double _iconBox = 96;

  /// Mağaza adresi bilinmiyorken kullanıcıya bırakılan yol. Düğmenin
  /// olmaması tek başına "peki ne yapayım" sorusunu cevaplamıyor.
  static const String _noStoreGuidance =
      'Bu cihaz için mağaza bağlantımız henüz yok. Uygulamayı kurduğun '
      'yerden güncelleyebilir, sorun sürerse destek@iskoala.com adresine '
      'yazabilirsin.';

  /// Verilen platformun mağaza adresi; o platformun kimliği boşsa `null`.
  ///
  /// Yedek yol **yok**. Kimlikler ikisi de boşken davranış doğruydu ama
  /// yalnız Android kimliği doldurulunca yedek yol iPhone kullanıcısını
  /// Google Play'e göndermeye başladı: hiçbir yere gitmeyen bir düğme
  /// olmayan düğmeden kötüyse, yanlış mağazaya giden düğme daha da kötü.
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

  /// Çalışılan platformun mağaza adresi. Düğmenin çizilip çizilmeyeceği de
  /// buradan geliyor: düğmenin varlığı ile açtığı adres tek bir değer, ayrı
  /// bir bayrak olsaydı biri değişip diğeri yerinde kalabilirdi.
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
