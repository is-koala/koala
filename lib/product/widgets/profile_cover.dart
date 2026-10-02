import 'package:flutter/material.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Bir kişinin profil kapağı: marka yeşili gradyan üstünde fotoğraf, ad,
/// meslek ve küçük etiketler (rol, konum).
///
/// İki ekran aynı kapağı çiziyor: işverenin aday sayfası
/// (`BUserProfilePage`) ve çalışanın başkasının profilini açtığı sayfa
/// (`PublicProfilePage`, is-koala/koala#182). Salt çizim; hangi veriyi nereden
/// bulacağı sayfanın işi.
///
/// Zemin temadan bağımsız marka yeşili, o yüzden üstündeki her şey de iki
/// temada aynı beyaz ([AppColors.onAccent]); `context`'ten renk okunmuyor.
class ProfileCover extends StatelessWidget {
  const ProfileCover({
    super.key,
    required this.name,
    this.imageUrl,
    this.subtitle,
    this.roleLabel,
    this.location,
  });

  /// Görünen ad.
  final String name;

  /// Profil fotoğrafı; yoksa ya da açılamazsa varsayılan koala görseli.
  final String? imageUrl;

  /// Adın altındaki satır, genelde meslek; boşsa çizilmiyor.
  final String? subtitle;

  /// Kişinin bağlamdaki rolü ("İşveren", "Çalışan" ...); boşsa etiket yok.
  final String? roleLabel;

  /// `Çankaya/Ankara`; boşsa etiket yok.
  final String? location;

  /// Kapaktaki profil fotoğrafı ve çevresindeki beyaz halka.
  static const double _avatarSize = 100;
  static const double _avatarBorder = 3;

  /// Gradyanın koyu ucunun opaklığı.
  static const double _gradientEndAlpha = 0.8;

  /// Kapak üzerindeki ikincil metin ve etiketlerin opaklıkları.
  static const double _onCoverMuted = 0.9;
  static const double _onCoverSurface = 0.2;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final roleLabel = this.roleLabel;
    final location = this.location;
    final badges = <Widget>[
      if (roleLabel != null && roleLabel.isNotEmpty)
        _badge(context, label: roleLabel),
      if (location != null && location.isNotEmpty)
        _badge(context, label: location, icon: AppIcons.location),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceXLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryColor,
            AppColors.primaryColor.withValues(alpha: _gradientEndAlpha),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.secondaryCircular,
              border: Border.all(
                color: AppColors.onAccent,
                width: _avatarBorder,
              ),
            ),
            child: ProfileAvatar(imageUrl: imageUrl, size: _avatarSize),
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          Text(
            name,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onAccent,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              subtitle,
              style: context.textTheme.bodyLarge?.copyWith(
                color: AppColors.onAccent.withValues(alpha: _onCoverMuted),
              ),
            ),
          ],
          if (badges.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSizes.spaceSmall,
              runSpacing: AppSizes.spaceSmall,
              children: badges,
            ),
          ],
        ],
      ),
    );
  }

  /// Kapak üstündeki yarı saydam hap: rol ya da konum.
  Widget _badge(
    BuildContext context, {
    required String label,
    AppIconData? icon,
  }) {
    final muted = AppColors.onAccent.withValues(alpha: _onCoverMuted);

    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: AppColors.onAccent.withValues(alpha: _onCoverSurface),
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon, size: AppSizes.iconSmall, color: muted),
            const SizedBox(width: AppSizes.spaceTiny),
          ],
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
