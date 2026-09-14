import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:provider/provider.dart';

/// Kimlik durumu rozeti: doğrulandı / incelemede / reddedildi /
/// doğrulanmadı. İki uygulamanın profili de çiziyor — çalışan profilinde
/// adın altında, işveren profilinde yeşil kapağın üstünde ([onAccentSurface]).
///
/// Bayrak `/users/me`'den, inceleme [IdentityReviewProvider]'dan; rozetin
/// kendisi okuma başlatmıyor, onu çizen profil sayfası her açılışta ve
/// yenilemede provider'ı tazeliyor. Doğrulanmamış hâllerde dokunmak kimlik
/// akışını açıyor; doğrulanmış rozet düz bir etiket.
class IdentityStatusBadge extends StatelessWidget {
  const IdentityStatusBadge({
    super.key,
    required this.user,
    this.onAccentSurface = false,
  });

  final CurrentUser user;

  /// Doygun yeşil kapak üstünde: renk kodu yerine beyaz metin, ikon ve
  /// çerçeve; yeşil üstünde yeşil rozet okunmazdı.
  final bool onAccentSurface;

  @override
  Widget build(BuildContext context) {
    final status = IdentityStatus.resolve(
      identityVerified: user.identityVerified,
      review: context.watch<IdentityReviewProvider>().review,
    );
    final color = onAccentSurface ? AppColors.onAccent : _colorFor(status);

    final chip = Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.stadiumCircular,
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(_iconFor(status), size: AppSizes.iconSmall, color: color),
          const SizedBox(width: AppSizes.spaceTiny),
          Text(
            status.label,
            style: context.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (status != IdentityStatus.verified) ...[
            const SizedBox(width: AppSizes.smallGap),
            AppIcon(
              AppIcons.arrowRight,
              size: AppSizes.iconSmall,
              color: color,
            ),
          ],
        ],
      ),
    );

    if (status == IdentityStatus.verified) return chip;

    return Semantics(
      button: true,
      label: '${status.label}, kimlik doğrulama ekranını aç',
      child: InkWell(
        onTap: () => context.push('/identity-verification', extra: user),
        borderRadius: AppRadius.stadiumCircular,
        child: chip,
      ),
    );
  }

  static Color _colorFor(IdentityStatus status) => switch (status) {
    IdentityStatus.verified => AppColors.success,
    IdentityStatus.pending => AppColors.pending,
    IdentityStatus.rejected => AppColors.danger,
    IdentityStatus.unverified => AppColors.warning,
  };

  static String _iconFor(IdentityStatus status) => switch (status) {
    IdentityStatus.verified => AppIcons.checkCircle,
    IdentityStatus.pending => AppIcons.clock,
    IdentityStatus.rejected => AppIcons.cancelCircle,
    IdentityStatus.unverified => AppIcons.alert,
  };
}
