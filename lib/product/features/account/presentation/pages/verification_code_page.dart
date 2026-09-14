import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/pending_verification.dart';
import 'package:koala/employee/features/auth/services/verification_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/settings_hint.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:provider/provider.dart';

part 'verification_code_pagemodel.dart';

/// E-posta ve telefon değişikliğinin 6 haneli kod ekranı.
///
/// `PATCH /users/me` yeni değeri yazmıyor: yeni adrese/numaraya bir kod
/// gönderip bekleyen doğrulamayı döndürüyor. Bu ekran o kodun girildiği yer;
/// onaylanana kadar eski değer geçerli kalıyor.
///
/// Ekrandaki bütün metinler uygulamada yazılı; sunucu yalnız doğrulamanın
/// türünü, hedefini ve son kullanma anını taşıyor.
class VerificationCodePage extends StatefulWidget {
  const VerificationCodePage({
    super.key,
    required this.verification,
    this.verificationService,
    this.onFinished,
    this.now,
  });

  /// Onaylanacak bekleyen doğrulama. Tekrar gönderimde yerini yenisi alıyor.
  final PendingVerification verification;

  /// Testlerde sahte sunucuya bağlı örnek geçilebilsin diye.
  final VerificationService? verificationService;

  /// Ekran kapanırken sonucu bildirir: doğrulama tamamlandıysa `true`,
  /// kayıt geçersiz olduğu için bırakıldıysa `false`. Verilmezse ekran
  /// kendini `context.pop(sonuç)` ile kapatıyor — çağıran sıradaki
  /// doğrulamaya geçip geçmeyeceğine buna bakarak karar veriyor.
  final ValueChanged<bool>? onFinished;

  /// Sayaç testlerinde zaman sınırını denetleyebilmek için kullanılan saat.
  /// Uygulamada verilmediğinde cihazın güncel saati okunur.
  final DateTime Function()? now;

  @override
  State<VerificationCodePage> createState() => _VerificationCodePageState();
}

class _VerificationCodePageState extends VerificationCodePagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Doğrulama Kodu'),
      bottomNavigationBar: ButtonNavbar(
        onPressed: isConfirming ? null : confirm,
        title: 'Onayla',
        isLoading: isConfirming,
      ),
      body: FormPageBody(
        padding: AppPadding.primaryAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(verification.instruction, style: context.textTheme.titleSmall),
            const SizedBox(height: AppSizes.spaceLarge),
            MyTextfield(
              labelText: 'Doğrulama Kodu',
              controller: code,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(
                  VerificationCodePagemodel.codeLength,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space),
            _remainingLine(),
            const SizedBox(height: AppSizes.spaceLarge),
            _resendRow(),
          ],
        ),
      ),
    );
  }

  /// Kalan süre sunucunun son kullanma anından hesaplanır. Eski sunucuda bu
  /// alan yoksa ekran açılışından başlayan yaklaşık süre gösterilir. Her iki
  /// durumda da geçerliliğe sunucu karar verdiği için giriş kapatılmaz.
  Widget _remainingLine() {
    return SettingsHint(
      hasTimeLeft
          ? 'Kodun geçerlilik süresi: $remainingLabel'
          : 'Kodun süresi dolmuş olabilir. Geçmediyse yeni bir kod isteyin.',
      padding: AppPadding.primaryLeft,
    );
  }

  /// Tekrar gönderme satırı. Soğuma süresi dolana kadar düğme kapalı;
  /// sunucunun tekrar gönderme ucu olmadığı için bu aslında `PATCH`'in
  /// tekrarı ve arka arkaya SMS gitmesi istenmiyor.
  Widget _resendRow() {
    return Container(
      width: double.infinity,
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kod ulaşmadı mı?',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          TextButton(
            onPressed: canResend ? resend : null,
            child: Text(
              'Kodu tekrar gönder',
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: canResend ? context.accentColor : context.textTertiary,
              ),
            ),
          ),
          if (resendCooldownSeconds > 0)
            SettingsHint(
              '$resendCooldownSeconds saniye sonra tekrar isteyebilirsiniz.',
              padding: AppPadding.primaryLeft,
            ),
        ],
      ),
    );
  }
}
