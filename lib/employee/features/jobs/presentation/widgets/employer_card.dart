import 'package:flutter/material.dart';
import 'package:koala/employee/core/widgets/employer_type_badge.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// İş detayındaki işveren kartı.
///
/// Şirket ilanında şirketin adı ve logosu; dokununca şirket sayfası açılıyor
/// ([onOpenCompany] verildiyse). Bireysel ilanda ilanı açan kişinin adı ve
/// fotoğrafı; dokununca kişinin herkese açık profili açılıyor
/// ([onOpenProfile] verildiyse, is-koala/koala#182). Ad henüz gelmediyse
/// (ilan detayı yükleniyor ya da eski sunucu) satır yer tutucuyla çiziliyor,
/// kart boş kalmıyor; kişinin kimliği de o zaman bilinmediği için dokunma
/// bağlanmıyor.
class EmployerCard extends StatelessWidget {
  const EmployerCard({
    super.key,
    required this.employerType,
    this.name,
    this.imageUrl,
    this.onOpenCompany,
    this.onOpenProfile,
  });

  final JobEmployerType employerType;

  /// Şirketin adı ya da kişinin ad soyadı.
  final String? name;

  /// Şirket logosu ya da kişinin profil fotoğrafı.
  final String? imageUrl;

  /// Şirket sayfasını açan dokunma; yalnızca şirket kimliği bilindiğinde.
  final VoidCallback? onOpenCompany;

  /// Bireysel işverenin profilini açan dokunma; yalnızca kişinin kimliği
  /// bilindiğinde. Şirket ilanında kullanılmıyor: orada kart şirketi
  /// gösteriyor.
  final VoidCallback? onOpenProfile;

  /// Avatar karesinin kenarı ve köşe yuvarlaklığı.
  static const double _avatarSize = AppSizes.avatar;

  bool get _isCompany => employerType == JobEmployerType.company;

  @override
  Widget build(BuildContext context) {
    final displayName = name ?? (_isCompany ? 'Şirket' : 'Bireysel işveren');
    final onTap = _isCompany ? onOpenCompany : onOpenProfile;
    final tappable = onTap != null;

    final content = Padding(
      padding: AppPadding.primaryAll,
      child: Row(
        children: [
          ChatAvatar(
            avatarUrl: imageUrl,
            fallbackText: Conversation.initialsOf(displayName),
            size: _avatarSize,
            borderRadius: AppRadius.inner,
          ),
          const SizedBox(width: AppSizes.space),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmployerTypeBadge(type: employerType),
                const SizedBox(height: AppSizes.spaceTiny),
                Text(
                  displayName,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tappable ? context.accentColor : null,
                  ),
                ),
              ],
            ),
          ),
          if (tappable)
            AppIcon(
              AppIcons.arrowRight,
              size: AppSizes.iconMedium,
              color: context.accentColor,
            ),
        ],
      ),
    );

    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: tappable
          ? InkWell(
              key: ValueKey(
                _isCompany ? 'employer-card-company' : 'employer-card-profile',
              ),
              borderRadius: AppRadius.innerCircular,
              onTap: onTap,
              child: content,
            )
          : content,
    );
  }
}
