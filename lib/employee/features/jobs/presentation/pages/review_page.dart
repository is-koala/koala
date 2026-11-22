import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/jobs/models/review.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

/// Tamamlanmış işi değerlendirme; iki kabuk açıyor, fark [ReviewSubject]'te.
/// Anonim yayın yalnız çalışana: işverenin "Değerlendirdiniz" satırı yazarı
/// bilinen kayda dayanıyor.
class ReviewPage extends StatefulWidget {
  final ReviewSubject subject;

  const ReviewPage({super.key, required this.subject});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isAnonymous = false;
  bool _isSubmitting = false;

  static const int _maxRating = 5;

  static const double _starSize = 52;

  static const double _jobIconBox = 52;

  static const double _radioSize = 24;

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

    final assignmentId = widget.subject.assignmentId;
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
      anonymous: !widget.subject.isEmployer && _isAnonymous,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!sent) {
      // `409` "zaten değerlendirilmiş" de buraya; sunucunun mesajı yeterli.
      AppToast.error(
        context,
        provider.errorMessage ?? 'Değerlendirme gönderilemedi',
      );
      return;
    }

    // Toast sayfa kapanmasından etkilenmiyor; önce gösterilip sonra kapanır.
    AppToast.success(context, 'Değerlendirmeniz gönderildi!');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: "Değerlendir"),
      body: FormPageBody(
        padding: AppPadding.primaryAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _jobInfoCard(),
            const SizedBox(height: AppSizes.spaceXLarge),
            _ratingSection(),
            const SizedBox(height: AppSizes.spaceXLarge),
            _commentSection(),
            if (!widget.subject.isEmployer) ...[
              const SizedBox(height: AppSizes.spaceLarge),
              _anonymousToggle(),
            ],
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
            child: Center(
              child: AppIcon(
                widget.subject.isEmployer ? AppIcons.user : AppIcons.work,
                color: context.accentColor,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spaceMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.subject.title, style: context.textTheme.titleSmall),
                const SizedBox(height: AppSizes.smallGap),
                Text(
                  widget.subject.subtitle,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                if (widget.subject.date != null) ...[
                  const SizedBox(height: AppSizes.smallGap),
                  Text(
                    widget.subject.date!.asShortDate,
                    style: context.textTheme.labelMedium,
                  ),
                ],
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
        _sectionSubtitle(
          widget.subject.isEmployer
              ? "Çalışanla deneyiminizi nasıl değerlendirirsiniz?"
              : "Bu iş deneyiminizi nasıl değerlendirirsiniz?",
        ),
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
          maxLength: Review.maxCommentLength,
          style: context.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.subject.isEmployer
                ? "Dakiklik, iletişim, işin kalitesi vb. hakkında..."
                : "İş ortamı, iletişim, ödeme süreci vb. hakkında...",
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

  // ----------------------------------------------------- Yayınlama tercihi

  /// Anonim yayın. Gizleme yalnız yanıtta: kayıt yazarına bağlı, puan
  /// ortalamaya girer. Sonradan değişmez.
  Widget _anonymousToggle() {
    return Container(
      padding: AppPadding.primaryAll,
      decoration: _panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Yayınlama Tercihi"),
          const SizedBox(height: AppSizes.space),
          _anonymousOption(
            title: "İsmimle Yayınla",
            subtitle: "Değerlendirmen adınla birlikte görünür",
            icon: Icons.person_rounded,
            isSelected: !_isAnonymous,
            onTap: () => setState(() => _isAnonymous = false),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          _anonymousOption(
            title: "Anonim Yayınla",
            subtitle: "Adın gizlenir, puanın yine sayılır",
            icon: Icons.visibility_off_rounded,
            isSelected: _isAnonymous,
            onTap: () => setState(() => _isAnonymous = true),
          ),
          if (_isAnonymous) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            // İşin iki tarafı var; değerlendirilen kişi kimin yazdığını
            // çıkarabilir. Anonimlik üçüncü kişilere karşı; söz büyük
            // verilmemeli.
            Text(
              'Adın profilinde ve listelerde görünmez. İşveren, hangi işe ait '
              'olduğundan yola çıkarak yine de tahmin edebilir.',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _anonymousOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final accent = context.accentColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _animation,
        padding: AppPadding.selectionCard,
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: _selectedTint)
              : context.backgroundColor,
          borderRadius: AppRadius.innerCircular,
          border: Border.all(
            color: isSelected ? accent : context.dividerColor,
            width: isSelected ? _selectedBorder : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? accent : context.textTertiary,
              size: AppSizes.icon,
            ),
            const SizedBox(width: AppSizes.space),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? accent : context.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? accent.withValues(alpha: _subtitleAlpha)
                          : context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: _animation,
              width: _radioSize,
              height: _radioSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accent : context.textTertiary,
                  width: _selectedBorder,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: context.onAccentColor,
                      size: AppSizes.iconSmall,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  static const double _selectedTint = 0.1;
  static const double _selectedBorder = 2;

  static const double _subtitleAlpha = 0.7;
}
