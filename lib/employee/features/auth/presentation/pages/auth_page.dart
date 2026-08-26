import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  /// Logonun yüksekliği. Kelime markasıyla birlikte tek bir blok oluşturuyor;
  /// ikisinin toplamı ekranın üst yarısını dolduracak kadar.
  static const double _logoHeight = 90;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(AppAssets.backgroundMap, fit: BoxFit.cover),
            ),
            Container(
              padding: AppPadding.primaryAll,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: AppSizes.spaceHuge),
                        SizedBox(
                          height: _logoHeight,
                          child: Image.asset(AppAssets.koalaLogoAlt),
                        ),
                        Text(
                          'KOALA',
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          // Arkadaki harita görseli iki temada da açık;
                          // yazı da o yüzden sabit koyu.
                          style: context.textTheme.displayLarge?.copyWith(
                            color: AppColors.onLightSurface,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        MyButton(
                          onPressed: () {
                            context.go('/auth/register-type');
                          },
                          title: 'KAYIT OL',
                        ),
                        const SizedBox(height: AppSizes.spaceMedium),
                        MyButton(
                          onPressed: () {
                            context.go('/auth/login');
                          },
                          title: 'GİRİŞ YAP',
                          isReversed: true,
                        ),
                        const SizedBox(height: AppSizes.sectionSpace),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
