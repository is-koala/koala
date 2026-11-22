import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final controller = PageController();
  bool isLastPage = false;
  double currentPage = 0.0;

  static const int _pageCount = 3;

  /// Görselin yanında, metnin üstüne binmeyecek yükseklikte.
  static const double _indicatorHeightRatio = 0.45;

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      setState(() {
        currentPage = controller.page ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          padding: AppPadding.primaryAll,
          child: Stack(
            children: [
              PageView(
                controller: controller,
                scrollDirection: Axis.vertical,
                onPageChanged: (index) {
                  setState(() {
                    isLastPage = index == _pageCount - 1;
                  });
                },
                children: const [
                  OnboardingContent(
                    imagePath: AppAssets.onboarding1,
                    title: "Günlük İş Bul",
                    description: "Sana yakın günlük iş ilanlarını keşfet ve hemen başvur",
                  ),
                  OnboardingContent(
                    imagePath: AppAssets.onboarding2,
                    title: "Hızlı Başvuru",
                    description: "Tek tıkla başvuru yap, işverenler seninle direkt iletişime geçsin",
                  ),
                  OnboardingContent(
                    imagePath: AppAssets.onboarding3,
                    title: "Kazanmaya Başla",
                    description: "İstediğin zamanlarda çalış, ek gelir elde et",
                  ),
                ],
              ),
              Positioned(
                right: AppSizes.spaceTiny,
                bottom:
                    MediaQuery.sizeOf(context).height * _indicatorHeightRatio,
                child: SmoothPageIndicator(
                  controller: controller,
                  axisDirection: Axis.vertical,
                  count: _pageCount,
                  effect: ExpandingDotsEffect(
                    dotHeight: AppSizes.badgeDot,
                    dotWidth: AppSizes.badgeDot,
                    spacing: AppSizes.spaceTiny,
                    activeDotColor: context.accentColor,
                    // smooth_page_indicator 3.0 renkleri temadan almıyor; pasif
                    // nokta iki temada okunsun diye elle.
                    dotColor: context.textTertiary,
                  ),
                ),
              ),
              Positioned(
                bottom: AppSizes.spaceSmall,
                left: 0,
                right: 0,
                child: _AnimatedButton(
                  currentPage: currentPage,
                  isLastPage: isLastPage,
                  onPressed: _onNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onNext() async {
    if (!isLastPage) {
      controller.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
      return;
    }

    await SessionManager().markOnboardingSeen();
    if (mounted) {
      context.go('/auth');
    }
  }
}

class OnboardingContent extends StatelessWidget {
  final String imagePath;
  final String title;
  final String description;

  const OnboardingContent({
    super.key,
    required this.imagePath,
    required this.title,
    required this.description,
  });

  static const double _imageHeight = 250;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(imagePath, height: _imageHeight, fit: BoxFit.contain),
        const SizedBox(height: AppSizes.spaceLarge),
        Text(
          title,
          style: context.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSizes.space),
        Text(
          description,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AnimatedButton extends StatelessWidget {
  final double currentPage;
  final bool isLastPage;
  final VoidCallback onPressed;

  const _AnimatedButton({
    required this.currentPage,
    required this.isLastPage,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final rawProgress = currentPage.clamp(0.0, 1.0);
    final progress = Curves.easeOutCubic.transform(rawProgress);
    final padding =
        AppPadding.primary * 2 + AppPadding.horizontalSmall.horizontal;
    final fullWidth = context.width - padding;
    const circularSize = AppSizes.buttonHeight;

    final buttonWidth = fullWidth - ((fullWidth - circularSize) * progress);
    const circularRadius = circularSize / 2;
    final borderRadius =
        AppRadius.primary + ((circularRadius - AppRadius.primary) * progress);

    // Metin ilk yarıda kaybolur, ikon ikinci yarıda belirir.
    final textOpacity = (1.0 - (progress * 2)).clamp(0.0, 1.0);
    final iconOpacity = ((progress - 0.5) * 2).clamp(0.0, 1.0);

    // İkinci geçiş: ok kaybolur, tik belirir.
    final secondProgress = (currentPage - 1.0).clamp(0.0, 1.0);
    final arrowOpacity = (1.0 - secondProgress).clamp(0.0, 1.0);
    final checkOpacity = secondProgress.clamp(0.0, 1.0);

    final buttonText = isLastPage ? 'HAYDİ BAŞLAYALIM!' : 'SONRAKİ';

    return Padding(
      padding: AppPadding.horizontalSmall,
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: buttonWidth,
          height: circularSize,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              backgroundColor: context.accentColor,
              overlayColor: AppColors.primarySoft,
              padding: AppPadding.button,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (textOpacity > 0)
                  Opacity(
                    opacity: textOpacity,
                    child: Text(
                      buttonText,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: context.onAccentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (iconOpacity > 0 && arrowOpacity > 0)
                  Opacity(
                    opacity: iconOpacity * arrowOpacity,
                    child: Icon(
                      Icons.arrow_downward,
                      color: context.onAccentColor,
                      size: AppSizes.icon,
                    ),
                  ),
                if (iconOpacity > 0 && checkOpacity > 0)
                  Opacity(
                    opacity: iconOpacity * checkOpacity,
                    child: Icon(
                      Icons.check,
                      color: context.onAccentColor,
                      size: AppSizes.icon,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
