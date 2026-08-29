import 'package:flutter/material.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

class ReviewPage extends StatefulWidget {
  final MyJob job;

  const ReviewPage({super.key, required this.job});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  static const int _maxRating = 5;

  /// Dokunulabilir yıldızın boyutu; ekranın ana eylemi olduğu için büyük.
  static const double _starSize = 52;

  /// İş bilgisi kartındaki ikon kutusu.
  static const double _jobIconBox = 52;

  static const Duration _animation = Duration(milliseconds: 200);

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      AppToast.error(context, 'Lütfen bir puan verin');
      return;
    }

    // Değerlendirme atamaya bırakılıyor; başvurudan gelen bir satırın atama
    // kimliği yok ve zaten "Değerlendir" butonu da o satırlarda çıkmıyor.
    final assignmentId = widget.job.assignmentId;
    if (assignmentId == null) {
      AppToast.error(context, 'Bu iş henüz değerlendirilemez');
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<ReviewProvider>();
    final comment = _commentController.text.trim();
    final sent = await provider.submitReview(
      assignmentId: assignmentId,
      rating: _rating,
      comment: comment.isEmpty ? null : comment,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!sent) {
      // 409 "zaten değerlendirilmiş" de buraya düşüyor; sunucunun mesajı
      // Türkçe geliyor ve durumu kullanıcıya olduğu gibi anlatıyor.
      AppToast.error(
        context,
        provider.errorMessage ?? 'Değerlendirme gönderilemedi',
      );
      return;
    }

    // Toast `ScaffoldMessenger`'a düşüyor, sayfanın kapanmasından
    // etkilenmiyor; o yüzden önce gösterilip sonra kapatılıyor.
    AppToast.success(context, 'Değerlendirmeniz gönderildi!');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: "Değerlendir"),
      body: SingleChildScrollView(
        padding: AppPadding.primaryAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _jobInfoCard(),
            const SizedBox(height: AppSizes.spaceXLarge),
            _ratingSection(),
            const SizedBox(height: AppSizes.spaceXLarge),
            _commentSection(),
            const SizedBox(height: AppSizes.navBarClearance),
          ],
        ),
      ),
      bottomNavigationBar: ButtonNavbar(
        onPressed: _submitReview,
        title: "Yorumu Yayınla",
        isLoading: _isSubmitting,
      ),
    );
  }

  // -------------------------------------------------------------- Ortak

  Widget _sectionTitle(String title) =>
      Text(title, style: context.textTheme.titleMedium);

  Widget _sectionSubtitle(String subtitle) => Text(
    subtitle,
    style: context.textTheme.bodyMedium?.copyWith(color: context.textSecondary),
  );

  BoxDecoration get _panelDecoration => BoxDecoration(
    color: context.tileColor,
    borderRadius: AppRadius.secondaryCircular,
  );

  // ------------------------------------------------------------ İş kartı

  Widget _jobInfoCard() {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: _panelDecoration,
      child: Row(
        children: [
          Container(
            width: _jobIconBox,
            height: _jobIconBox,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.15),
              borderRadius: AppRadius.innerCircular,
            ),
            child: Icon(
              Icons.work_outline_rounded,
              color: context.accentColor,
              size: AppSizes.icon,
            ),
          ),
          const SizedBox(width: AppSizes.spaceMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.job.title, style: context.textTheme.titleSmall),
                const SizedBox(height: AppSizes.smallGap),
                Text(
                  widget.job.company,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.smallGap),
                Text(widget.job.date, style: context.textTheme.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- Puanlama

  Widget _ratingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Puanınız"),
        const SizedBox(height: AppSizes.spaceTiny),
        _sectionSubtitle("Bu iş deneyiminizi nasıl değerlendirirsiniz?"),
        const SizedBox(height: AppSizes.spaceMedium),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_maxRating, (index) {
            final starIndex = index + 1;
            final isFilled = starIndex <= _rating;

            return GestureDetector(
              onTap: () => setState(() => _rating = starIndex),
              child: AnimatedContainer(
                duration: _animation,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spaceTiny,
                ),
                child: Icon(
                  isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFilled ? AppColors.rating : context.dividerColor,
                  size: _starSize,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSizes.spaceSmall),
        Center(
          child: AnimatedSwitcher(
            duration: _animation,
            child: Text(
              _ratingLabel(),
              key: ValueKey(_rating),
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: _rating > 0
                    ? AppColors.ratingStrong
                    : context.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _ratingLabel() {
    switch (_rating) {
      case 1:
        return 'Çok Kötü';
      case 2:
        return 'Kötü';
      case 3:
        return 'Orta';
      case 4:
        return 'İyi';
      case 5:
        return 'Mükemmel';
      default:
        return 'Bir yıldıza dokunun';
    }
  }

  // ---------------------------------------------------------------- Yorum

  Widget _commentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Yorumunuz"),
        const SizedBox(height: AppSizes.spaceTiny),
        _sectionSubtitle("Deneyiminizi detaylı anlatın (opsiyonel)"),
        const SizedBox(height: AppSizes.space),
        TextField(
          controller: _commentController,
          maxLines: 5,
          maxLength: 500,
          style: context.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: "İş ortamı, iletişim, ödeme süreci vb. hakkında...",
            hintStyle: context.textTheme.bodyMedium?.copyWith(
              color: context.textTertiary,
            ),
            filled: true,
            fillColor: context.tileColor,
            border: _fieldBorder(context.dividerColor),
            enabledBorder: _fieldBorder(context.dividerColor),
            focusedBorder: _fieldBorder(context.accentColor, width: 2),
            contentPadding: AppPadding.primaryAll,
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.innerCircular,
        borderSide: BorderSide(color: color, width: width),
      );
}
