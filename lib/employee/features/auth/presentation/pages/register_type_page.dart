import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterTypePage extends StatelessWidget {
  const RegisterTypePage({super.key});

  /// Seçim kartındaki görselin ölçüsü. Dikey dikdörtgen: maskot boydan
  /// görünsün ve kart yüksekliğini görsel belirlesin diye.
  static const double _cardImageWidth = 100;
  static const double _cardImageHeight = 150;

  /// Kartın kenarlık kalınlığı; kart zeminsiz olduğu için seçilebilir
  /// olduğunu yalnızca bu çerçeve anlatıyor.
  static const double _cardBorderWidth = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: context.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              padding: AppPadding.authContentWide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ne olmak istersin?",
                    style: context.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceHuge),
                  _typeCard(
                    context,
                    imagePath: AppAssets.koalaBusiness,
                    title: 'İş Veren',
                    subtitle: 'İş yeriniz için',
                    isBusiness: true,
                  ),
                  const SizedBox(height: AppSizes.spaceMedium),
                  _typeCard(
                    context,
                    imagePath: AppAssets.koalaWorker,
                    title: 'Çalışan',
                    subtitle: 'Para kazanmak için',
                    isBusiness: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeCard(
    BuildContext context, {
    required String imagePath,
    required String title,
    required String subtitle,
    required bool isBusiness,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.primaryCircular,
        side: BorderSide(color: context.accentColor, width: _cardBorderWidth),
      ),
      child: InkWell(
        splashColor: AppColors.primaryTint,
        highlightColor: AppColors.primarySoft,
        borderRadius: AppRadius.primaryCircular,
        onTap: () => _onTypeSelected(context, isBusiness: isBusiness),
        child: Container(
          padding: AppPadding.selectionCard,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppRadius.smallCircular,
                child: Image.asset(
                  imagePath,
                  width: _cardImageWidth,
                  height: _cardImageHeight,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: AppSizes.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.textTheme.titleLarge),
                    const SizedBox(height: AppSizes.spaceTiny),
                    Text(
                      subtitle,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: context.textSecondary,
                size: AppSizes.icon,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTypeSelected(
    BuildContext context, {
    required bool isBusiness,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBusiness', isBusiness);

    if (context.mounted) {
      context.push('/auth/register-type/register?isBusiness=$isBusiness');
    }
  }
}
