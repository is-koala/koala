import 'package:material_ui/material_ui.dart';
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

/// İşveren kartı: şirkette ad + logo (şirket sayfası), bireyselde ad + fotoğraf
/// (profil, #182). Ad gelmediyse yer tutucu; kimlik bilinmiyorsa dokunma yok.
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

  final String? name;

  final String? imageUrl;

  final VoidCallback? onOpenCompany;

  /// Yalnız bireysel ilanda.
  final VoidCallback? onOpenProfile;

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
