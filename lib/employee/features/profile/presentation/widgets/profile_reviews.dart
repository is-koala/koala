import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/rating_summary_badge.dart';
import 'package:koala/product/widgets/review_tile.dart';

/// Kullanıcı hakkında yazılmış değerlendirmeler ve puan özeti.
///
/// Kendi verisini kendisi çekiyor: iki ayrı uç (`/users/{id}/rating-summary`
/// ve `/users/{id}/reviews`) ve ikisi de profilin geri kalanından bağımsız.
/// Bu yüzden bölüm başarısız olduğunda profil boşalmıyor, yalnızca bu şerit
/// hatayı gösteriyor.
class ProfileReviews extends StatefulWidget {
  const ProfileReviews({
    super.key,
    required this.userId,
    this.service,
    this.emptyMessage,
    this.summary,
  });

  /// Hakkında değerlendirme okunacak kişi.
  final String userId;

  /// Testlerde sahte sunucuya bağlı servis; verilmezse üretim tekili.
  final ReviewService? service;

  /// Hiç değerlendirme yokken yazılan cümle. Varsayılanı profilin sahibine
  /// konuşuyor ("Henüz değerlendirilmedin"); başkasının profilinde bu cümle
  /// yanlış olurdu, orada çağıran kendi cümlesini veriyor.
  final String? emptyMessage;

  /// Çağıranın zaten bildiği puan özeti. Verilirse `rating-summary` ucu
  /// çağrılmıyor (başkasının profilinde `GET /users/{id}` özeti taşıyor);
  /// `reviewCount`'u sıfır olan özet "henüz puan yok" çiziyor. Verilmezse —
  /// kendi profili, eski sunucu — özet kendi ucundan çekiliyor.
  final RatingSummary? summary;

  /// Kendi profilinde boş durumun cümlesi.
  static const String ownEmptyMessage =
      'Henüz değerlendirilmedin. Tamamladığın işlerden sonra işverenler '
      'buraya yazabilir.';

  @override
  State<ProfileReviews> createState() => _ProfileReviewsState();
}

class _ProfileReviewsState extends State<ProfileReviews> {
  late final ReviewService _service = widget.service ?? ReviewService();

  /// Listede gösterilen yorum sayısı. Profil bir değerlendirme sayfası değil;
  /// tamamı için ayrı bir ekran gerekir.
  static const int _visibleCount = 3;

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
      // Çağıran özeti zaten biliyorsa (profil yanıtı taşıyor) ayrı uç
      // çağrılmıyor.
      final known = widget.summary;
      final Future<RatingSummary?> summary = known != null
          ? Future<RatingSummary?>.value(known)
          : _service.fetchRatingSummary(widget.userId);
      final results = await Future.wait([
        summary,
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
          for (final review in _reviews)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.space),
              child: ReviewTile(review: review),
            ),
      ],
    );
  }

  Widget _header() {
    final summary = _summary;
    final muted = context.textTheme.labelMedium?.copyWith(
      color: context.textTertiary,
    );

    return Row(
      children: [
        Text(
          'Değerlendirmeler',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (summary != null && summary.hasRating)
          KeyedSubtree(
            key: const ValueKey('profile-rating-summary'),
            child: RatingSummaryBadge(summary: summary),
          )
        else if (_errorMessage == null)
          Text(
            'Henüz puan yok',
            key: const ValueKey('profile-no-rating'),
            style: muted,
          ),
      ],
    );
  }

  Widget _emptyText() => Text(
    widget.emptyMessage ?? ProfileReviews.ownEmptyMessage,
    key: const ValueKey('profile-no-reviews'),
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
}
