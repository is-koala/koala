import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_exception.dart';

/// Kullanıcı hakkında yazılmış değerlendirmeler ve puan özeti.
///
/// Kendi verisini kendisi çekiyor: iki ayrı uç (`/users/{id}/rating-summary`
/// ve `/users/{id}/reviews`) ve ikisi de profilin geri kalanından bağımsız.
/// Bu yüzden bölüm başarısız olduğunda profil boşalmıyor, yalnızca bu şerit
/// hatayı gösteriyor.
class ProfileReviews extends StatefulWidget {
  const ProfileReviews({super.key, required this.userId, this.service});

  /// Hakkında değerlendirme okunacak kişi.
  final String userId;

  /// Testlerde sahte sunucuya bağlı servis; verilmezse üretim tekili.
  final ReviewService? service;

  @override
  State<ProfileReviews> createState() => _ProfileReviewsState();
}

class _ProfileReviewsState extends State<ProfileReviews> {
  late final ReviewService _service = widget.service ?? ReviewService();

  /// Listede gösterilen yorum sayısı. Profil bir değerlendirme sayfası değil;
  /// tamamı için ayrı bir ekran gerekir.
  static const int _visibleCount = 3;

  /// Puan rozetindeki yıldızın boyutu.
  static const double _summaryStarSize = 20;

  /// Yorum satırındaki yazar fotoğrafı.
  static const double _authorAvatarSize = 36;

  static const int _maxRating = 5;

  RatingSummary? _summary;
  List<Review> _reviews = const [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileReviews oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // İkisi paralel gidiyor; özet, yorum listesinden bağımsız bir uç.
      final results = await Future.wait([
        _service.fetchRatingSummary(widget.userId),
        _service.fetchReviewsAbout(widget.userId, size: _visibleCount),
      ]);

      if (!mounted) return;
      setState(() {
        _summary = results[0] as RatingSummary?;
        _reviews = (results[1] as ReviewPage).reviews;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.spaceLarge),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final error = _errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: AppSizes.space),
        if (error != null)
          _errorStrip(error)
        else if (_reviews.isEmpty)
          _emptyText()
        else
          ..._reviews.map(_reviewTile),
      ],
    );
  }

  /// Başlık ve puan rozeti aynı satırda.
  Widget _header() {
    final summary = _summary;

    return Row(
      children: [
        Text(
          'Değerlendirmeler',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        // Değerlendirmesi olmayana "0.0" yazmak onu kötü puanlı gösterirdi.
        if (summary != null && summary.hasRating) _summaryBadge(summary),
      ],
    );
  }

  Widget _summaryBadge(RatingSummary summary) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.star_rounded,
          color: AppColors.rating,
          size: _summaryStarSize,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          summary.averageRating.toStringAsFixed(1),
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          '(${summary.reviewCount})',
          style: context.textTheme.labelMedium?.copyWith(
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _emptyText() => Text(
    'Henüz değerlendirilmedin. Tamamladığın işlerden sonra işverenler '
    'buraya yazabilir.',
    style: context.textTheme.bodyMedium?.copyWith(color: context.textSecondary),
  );

  /// Değerlendirmeler çekilemediğinde: mesaj ve tekrar deneme.
  ///
  /// Profilin geri kalanı yerinde kalıyor; bu bölüm profilin tamamlayıcısı,
  /// ön koşulu değil.
  Widget _errorStrip(String message) {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          OutlinedButton(onPressed: _load, child: const Text('Tekrar Dene')),
        ],
      ),
    );
  }

  Widget _reviewTile(Review review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Anonim değerlendirmede yazar hiç gelmiyor; varsayılan koala
          // görseli zaten `ProfileAvatar`'ın boş durumu.
          ProfileAvatar(
            imageUrl: review.author?.profilePictureUrl,
            size: _authorAvatarSize,
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
                          // Anonim satır bir kişiyi işaret etmiyor; adı
                          // soluk yazmak bunu görsel olarak da söylüyor.
                          color: review.isAnonymous
                              ? context.textSecondary
                              : null,
                          fontStyle: review.isAnonymous
                              ? FontStyle.italic
                              : null,
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
                _stars(review.rating),
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
      ),
    );
  }

  Widget _stars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_maxRating, (index) {
        final isFilled = index < rating;

        return Icon(
          isFilled ? Icons.star_rounded : Icons.star_border_rounded,
          color: isFilled ? AppColors.rating : context.dividerColor,
          size: AppSizes.iconSmall,
        );
      }),
    );
  }
}
