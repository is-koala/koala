import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/rating_stars.dart';

/// Tek değerlendirme satırı. Anonimde yazar gelmiyor: varsayılan görsel ve
/// soluk "Anonim", satır bir kişiyi işaret etmiyor.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});

  final Review review;

  static const double _avatarSize = 36;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileAvatar(
          imageUrl: review.author?.profilePictureUrl,
          size: _avatarSize,
        ),
        const SizedBox(width: AppSizes.space),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.authorLabel,
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: review.isAnonymous
                            ? context.textSecondary
                            : null,
                        fontStyle: review.isAnonymous ? FontStyle.italic : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (review.createdAt != null)
                    Text(
                      review.createdAt!.asShortDate,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.smallGap),
              RatingStars(rating: review.rating),
              if (review.hasComment) ...[
                const SizedBox(height: AppSizes.spaceTiny),
                Text(
                  review.comment!,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
