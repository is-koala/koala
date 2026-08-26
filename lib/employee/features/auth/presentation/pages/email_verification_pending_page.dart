import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailVerificationPendingPage extends StatelessWidget {
  const EmailVerificationPendingPage({super.key, required this.isBusiness});

  final bool isBusiness;

  /// Bekleme animasyonunun kenar uzunluğu; sayfanın tek görseli olduğu için
  /// diğer ekranlardaki görsellerden büyük.
  static const double _animationSize = 300;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppPadding.primaryAll,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: _animationSize,
                  height: _animationSize,
                  child: Lottie.asset(
                    AppAssets.emailVerificationPending,
                    fit: BoxFit.cover,
                  ),
                ),
                Text(
                  "E-posta doğrulama bekleniyor",
                  style: context.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.spaceMedium),
                Text(
                  "Lütfen e-posta adresinize gelen doğrulama linkine tıklayın.",
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.sectionSpace),
                // TODO(backend): Gerçek doğrulama akışı bağlanınca kaldırılacak.
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('is_logged_in', true);
                    await prefs.setString(
                      'user_type',
                      isBusiness ? 'business' : 'employee',
                    );

                    if (context.mounted) {
                      context.go(isBusiness ? '/business/home' : '/explore');
                    }
                  },
                  child: Text(
                    isBusiness
                        ? 'İş Veren Arayüzünü Gör (Demo)'
                        : 'Çalışan Arayüzünü Gör (Demo)',
                    style: context.textTheme.labelLarge?.copyWith(
                      color: context.accentColor,
                    ),
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
