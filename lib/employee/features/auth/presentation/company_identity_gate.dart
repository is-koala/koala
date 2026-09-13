import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:provider/provider.dart';

/// Şirket kurmanın kimlik kapısı.
///
/// Sunucu `POST /companies`'i `identityVerified` olmayan kullanıcıda
/// `USER_MUST_VERIFY_IDENTITY` ile reddediyor (`CompanyManager.addCompany`,
/// `400`). Kapı iki yerde tutuluyor: şirket türü seçilirken ve ayarlardan
/// şirket kurulurken **önden** ([ensureVerified]), formun kendisinde ise
/// sunucunun reddi geldiğinde ([isIdentityRequired] → [startVerification])
/// — kullanıcı arada başka bir cihazdan kimliğini silmiş olabilir. İkisi de
/// aynı onarım akışını açıyor ki kullanıcı ham bir hata metniyle formda
/// kilitlenmesin (is-koala/koala#134).
///
/// Güvenlik politikasına dokunmuyor: doğrulamayı sunucu istiyor, burası
/// yalnız kullanıcıyı o kapıdan doğru sırayla geçiriyor.
abstract final class CompanyIdentityGate {
  /// Sunucunun kimlik zorunluluğunu bildirdiği kod. Karar buna bakıyor,
  /// mesaj metnine değil: metin yerelleşiyor, kod `{user.must.verify.identity}`
  /// anahtarından türüyor.
  static const String identityRequiredCode = 'USER_MUST_VERIFY_IDENTITY';

  /// Sunucunun reddi "önce kimliğini doğrula" mı diyor.
  static bool isIdentityRequired(ApiException error) =>
      error.errorCode == identityRequiredCode;

  /// Kullanıcının kimliği doğrulanmışsa `true`; değilse doğrulama akışını
  /// açıp sonucuna göre döner ([startVerification]).
  ///
  /// Formu açmadan **önce** çağrılıyor: `/users/me` bayrağı doğrulanmış
  /// diyorsa sunucuya gidilmeden geçiliyor. Sunucu yine de reddederse form
  /// [startVerification] ile aynı akışı açıyor.
  static Future<bool> ensureVerified(BuildContext context) async {
    final provider = context.read<UserProvider>();
    final user = await _currentUser(context, provider);
    if (user == null) return false;

    if (user.identityVerified) return true;
    if (!context.mounted) return false;

    return _verify(context, provider, user);
  }

  /// Doğrulama akışını yerel bayrağa bakmadan açar.
  ///
  /// Sunucu şirketi `USER_MUST_VERIFY_IDENTITY` ile reddettiğinde
  /// çağrılıyor. O anda `/users/me` kopyası "doğrulanmış" diyor olabilir —
  /// eski bir yanıt, başka cihazdan yapılan bir değişiklik — ve bayrağa
  /// güvenen [ensureVerified] hiçbir şey açmadan `true` döner, kullanıcı da
  /// hatasız ama çıkışsız bir formda kalırdı. Sunucunun reddi son söz.
  static Future<bool> startVerification(BuildContext context) async {
    final provider = context.read<UserProvider>();
    final user = await _currentUser(context, provider);
    if (user == null || !context.mounted) return false;

    return _verify(context, provider, user);
  }

  /// Eldeki kullanıcı; yoksa `/users/me` okunuyor.
  ///
  /// Kayıt yeni bittiğinde hiçbir ekran daha kullanıcıyı çekmemiş oluyor.
  /// Okunamazsa `null` ve sebebi söyleniyor: kapı bilinmeyen bir
  /// kullanıcıyı geçirmiyor.
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

  /// Neden gerektiğini anlatan kutu → kimlik doğrulama ekranı → `/users/me`.
  ///
  /// Ekran başarıyla kapanınca kullanıcı yeniden okunuyor ve karar **taze
  /// bayrağa** göre veriliyor, sayfanın döndürdüğü `true`'ya değil. Vazgeçen
  /// ya da geri dönen kullanıcı için `false`: çağıran taraf olduğu yerde
  /// kalıyor ve gittiği yer kaybolmuyor.
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
      // Yıkıcı bir işlem değil, yönlendirme: kırmızı düğme yanlış sinyal.
      isDestructive: false,
    );
    if (confirmed != true || !context.mounted) return false;

    final verified = await context.push<bool>(
      '/identity-verification',
      extra: user,
    );
    if (verified != true || !context.mounted) return false;

    // Kimlik ekranı kapanmadan `/users/me`'yi tazeliyor; yine de burada bir
    // kez daha okunuyor ki kapının kararı ekranın sözüne değil sunucudaki
    // bayrağa dayansın.
    await provider.load(silent: true);
    return provider.user?.identityVerified == true;
  }
}
