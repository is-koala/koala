import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:lottie/lottie.dart';

class EmailVerificationPendingPage extends StatelessWidget {
  const EmailVerificationPendingPage({
    super.key,
    required this.isBusiness,
    this.email,
  });

  final bool isBusiness;

  /// Doğrulama postasının gittiği adres. Kayıt ekranından geliyor; derin
  /// bağlantıyla doğrudan bu sayfaya düşüldüğünde `null` olabilir.
  final String? email;

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
                  email == null
                      ? "Lütfen e-posta adresinize gelen doğrulama linkine tıklayın."
                      : "Doğrulama linkini $email adresine gönderdik. "
                            "Lütfen gelen linke tıklayın.",
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
