import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Profil kapağı: yeşil gradyan üstünde fotoğraf, ad, meslek ve etiketler. Aday
/// sayfası ve herkese açık profil kullanıyor. Zemin temadan bağımsız, o yüzden
/// içerik iki temada da [AppColors.onAccent].
class ProfileCover extends StatelessWidget {
  const ProfileCover({
    super.key,
    required this.name,
    this.imageUrl,
    this.subtitle,
    this.roleLabel,
    this.location,
  });

  final String name;

  /// Yoksa ya da açılamazsa varsayılan koala görseli.
  final String? imageUrl;

  /// Genelde meslek; boşsa çizilmez.
  final String? subtitle;

  /// Bağlamdaki rol ("İşveren", "Çalışan"); boşsa etiket yok.
  final String? roleLabel;

  final String? location;

  static const double _avatarSize = 100;
  static const double _avatarBorder = 3;

  static const double _gradientEndAlpha = 0.8;

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
