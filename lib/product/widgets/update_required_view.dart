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
  const UpdateRequiredView({super.key, required this.message});

  /// Sunucunun gönderdiği açıklama.
  final String message;

  /// İkonu taşıyan kutunun kenar uzunluğu.
  static const double _iconBox = 96;

  /// Mağaza bağlantısı biliniyor mu. Kimlikler doldurulmadan düğme
  /// çizilmiyor: hiçbir yere gitmeyen bir düğme, olmayan düğmeden kötü.
  static bool get _hasStoreLink =>
      AppInfo.androidPackageId.isNotEmpty || AppInfo.iosAppStoreId.isNotEmpty;

  static Uri? _storeUri() {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        AppInfo.iosAppStoreId.isNotEmpty) {
      return Uri.parse('https://apps.apple.com/app/id${AppInfo.iosAppStoreId}');
    }

    if (AppInfo.androidPackageId.isNotEmpty) {
      return Uri.parse(
        'https://play.google.com/store/apps/details?id='
        '${AppInfo.androidPackageId}',
      );
    }

    return null;
  }

  Future<void> _openStore() async {
    final uri = _storeUri();
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
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
                if (_hasStoreLink) ...[
                  const SizedBox(height: AppSizes.spaceXLarge),
                  MyButton(title: 'Mağazayı Aç', onPressed: _openStore),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
