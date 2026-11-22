import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:provider/provider.dart';

/// Şirket kurmanın kimlik kapısı: sunucu doğrulanmamış kullanıcıyı
/// `USER_MUST_VERIFY_IDENTITY` ile reddediyor. Kapı önden ([ensureVerified]) ve
/// sunucunun reddinde ([startVerification]) tutuluyor; ikisi aynı onarım
/// akışını açar ki kullanıcı formda kilitlenmesin (#134).
abstract final class CompanyIdentityGate {
  /// Karar koda bakıyor; metin yerelleşiyor.
  static const String identityRequiredCode = 'USER_MUST_VERIFY_IDENTITY';

  static bool isIdentityRequired(ApiException error) =>
      error.errorCode == identityRequiredCode;

  /// Doğrulanmışsa `true`; değilse akışı açıp sonucuna göre döner. Formdan
  /// **önce** çağrılıyor.
  static Future<bool> ensureVerified(BuildContext context) async {
    final provider = context.read<UserProvider>();
    final user = await _currentUser(context, provider);
    if (user == null) return false;

    if (user.identityVerified) return true;
    if (!context.mounted) return false;

    return _verify(context, provider, user);
  }

  /// Akışı yerel bayrağa bakmadan açar. Sunucu reddettiğinde `/users/me`
  /// kopyası bayat olabilir; sunucunun reddi son söz.
  static Future<bool> startVerification(BuildContext context) async {
    final provider = context.read<UserProvider>();
    final user = await _currentUser(context, provider);
    if (user == null || !context.mounted) return false;

    return _verify(context, provider, user);
  }

  /// Eldeki kullanıcı, yoksa `/users/me`. Okunamazsa `null`: kapı bilinmeyen
  /// kullanıcıyı geçirmez.
  static Future<CurrentUser?> _currentUser(
    BuildContext context,
    UserProvider provider,
  ) async {
    var user = provider.user;
    if (user == null) {
      await provider.load(silent: true);
      if (!context.mounted) return null;
      user = provider.user;
    }
    if (user == null) {
      AppToast.error(
        context,
        provider.errorMessage ?? 'Kullanıcı bilgileri alınamadı',
      );
    }
    return user;
  }

  /// Açıklama → kimlik ekranı → `/users/me`. Karar sayfanın `true`'suna değil
  /// **taze bayrağa** göre; vazgeçen için `false`.
  static Future<bool> _verify(
    BuildContext context,
    UserProvider provider,
    CurrentUser user,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Kimlik doğrulaması gerekli',
      message:
          'Şirket kurabilmek için önce kimliğinizi doğrulamanız gerekiyor. '
          'Doğrulama birkaç dakika sürüyor ve bir kez yapılıyor; bittiğinde '
          'şirket formuna devam edeceksiniz.',
      actionLabel: 'Doğrula',
      // Yönlendirme, yıkıcı değil.
      isDestructive: false,
    );
    if (confirmed != true || !context.mounted) return false;

    final verified = await context.push<bool>(
      '/identity-verification',
      extra: user,
    );
    if (verified != true || !context.mounted) return false;

    // Karar ekranın sözüne değil sunucudaki bayrağa dayansın.
    await provider.load(silent: true);
    return provider.user?.identityVerified == true;
  }
}
