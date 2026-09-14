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

/// Profildeki kimlik durumu rozeti: doğrulandı / incelemede / reddedildi /
/// doğrulanmadı.
///
/// Bayrak `/users/me`'den, inceleme [IdentityReviewProvider]'dan. Provider
/// henüz sormadıysa rozet çizilirken sessizce sorduruyor — açılışta
/// başlatılan okuma çoğu zaman bitmiş oluyor, bitmemişse burada
/// tamamlanıyor. Doğrulanmamış hâllerde dokunmak kimlik akışını açıyor;
/// doğrulanmış rozet düz bir etiket.
///
/// Provider ağaçta yoksa rozet yalnız bayrağa göre çiziliyor: iş tarafı da
/// aynı widget'ı kullanıyor ve iki uygulamanın testleri farklı provider
/// kümeleriyle kuruluyor.
class IdentityStatusBadge extends StatefulWidget {
  const IdentityStatusBadge({super.key, required this.user});

  final CurrentUser user;

  @override
  State<IdentityStatusBadge> createState() => _IdentityStatusBadgeState();
}

class _IdentityStatusBadgeState extends State<IdentityStatusBadge> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  /// Doğrulanmış kullanıcı için inceleme sorulmuyor: cevabı bayrak veriyor.
  void _ensureLoaded() {
    if (!mounted || widget.user.identityVerified) return;
    final provider = context.read<IdentityReviewProvider?>();
    if (provider == null || provider.hasLoaded || provider.isLoading) return;
    provider.load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IdentityReviewProvider?>();
    final status = IdentityStatus.resolve(
      identityVerified: widget.user.identityVerified,
      review: provider?.review,
    );
    final palette = _paletteFor(status);

    final chip = Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: palette.color.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.stadiumCircular,
        border: Border.all(color: palette.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(palette.icon, size: AppSizes.iconSmall, color: palette.color),
          const SizedBox(width: AppSizes.spaceTiny),
          Text(
            status.label,
            style: context.textTheme.labelMedium?.copyWith(
              color: palette.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (status != IdentityStatus.verified) ...[
            const SizedBox(width: AppSizes.smallGap),
            AppIcon(
              AppIcons.arrowRight,
              size: AppSizes.iconSmall,
              color: palette.color,
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
        onTap: () => context.push('/identity-verification', extra: widget.user),
        borderRadius: AppRadius.stadiumCircular,
        child: chip,
      ),
    );
  }

  static _BadgePalette _paletteFor(IdentityStatus status) => switch (status) {
    IdentityStatus.verified => const _BadgePalette(
      AppColors.success,
      AppIcons.checkCircle,
    ),
    IdentityStatus.pending => const _BadgePalette(
      AppColors.pending,
      AppIcons.clock,
    ),
    IdentityStatus.rejected => const _BadgePalette(
      AppColors.danger,
      AppIcons.cancelCircle,
    ),
    IdentityStatus.unverified => const _BadgePalette(
      AppColors.warning,
      AppIcons.alert,
    ),
  };
}

class _BadgePalette {
  const _BadgePalette(this.color, this.icon);

  final Color color;
  final String icon;
}
