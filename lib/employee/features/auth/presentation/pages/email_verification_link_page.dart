import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:lottie/lottie.dart';

/// E-posta doğrulama bağlantısını ilgili hesap akışı tamamlanana kadar
/// güvenli biçimde karşılayan geçici ekran.
class EmailVerificationLinkPage extends StatelessWidget {
  const EmailVerificationLinkPage({super.key, required this.token});

  /// Bağlantıdan gelen ve ileride doğrulama servisine aktarılacak token.
  ///
  /// Kullanıcı arayüzünde veya loglarda gösterilmez.
  final String token;

  /// Bekleme animasyonunun kenar uzunluğu.
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
                  'E-posta doğrulama bağlantın alındı',
                  style: context.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.spaceMedium),
                Text(
                  'Doğrulama işleminin sonraki adımı burada gösterilecek.',
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
