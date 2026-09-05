part of 'change_password_page.dart';

abstract class ChangePasswordPagemodel extends State<ChangePasswordPage> {
  final TextEditingController currentPassword = TextEditingController();
  final TextEditingController newPassword = TextEditingController();
  final TextEditingController confirmation = TextEditingController();

  bool isCurrentHidden = true;
  bool isNewHidden = true;
  bool isConfirmationHidden = true;
  bool isSaving = false;

  UserService get _userService => widget.userService ?? UserService();

  @override
  void dispose() {
    currentPassword.dispose();
    newPassword.dispose();
    confirmation.dispose();
    super.dispose();
  }

  /// Girdileri doğrulayıp parolayı değiştirir.
  ///
  /// Dört doğrulama da sunucuya gitmeden yapılıyor. Backend bunların
  /// hepsini `400` ile reddediyor zaten; ağ turu beklemeden söylemek
  /// kullanıcının işine yarıyor.
  Future<void> submit() async {
    final current = currentPassword.text;
    final next = newPassword.text;
    final repeated = confirmation.text;

    if (current.isEmpty || next.isEmpty || repeated.isEmpty) {
      AppToast.error(context, 'Bütün alanları doldur.');
      return;
    }
    if (!PasswordRule.isSatisfiedBy(next)) {
      AppToast.error(context, PasswordRule.requirement);
      return;
    }
    if (next != repeated) {
      AppToast.error(context, 'Şifreler eşleşmiyor.');
      return;
    }
    if (next == current) {
      AppToast.error(context, 'Yeni şifren mevcut şifrenden farklı olmalı.');
      return;
    }

    setState(() => isSaving = true);
    try {
      await _userService.changePassword(
        currentPassword: current,
        newPassword: next,
        confirmNewPassword: repeated,
      );
      if (!mounted) return;

      // Bu cihazın oturumu sunucuda açık kalıyor; kullanıcıdan yeniden
      // giriş istemek gereksiz olurdu.
      AppToast.success(
        context,
        'Şifren güncellendi. Diğer cihazlardaki oturumların kapatıldı.',
      );

      final onCompleted = widget.onCompleted;
      if (onCompleted != null) {
        onCompleted();
      } else {
        context.pop();
      }
    } on ApiException catch (error) {
      // Mevcut parola yanlışken sunucu `400` dönüyor: `UserManager`
      // `ValidationException` fırlatıyor ve `GlobalExceptionHandler` onu
      // `400`'e çeviriyor. `UsersController`'ın `@ApiResponse`'u `401`
      // yazsa da gerçek davranış bu.
      //
      // Yine de `401` gelirse: `AuthInterceptor` token'ı bir kez tazeleyip
      // isteği tekrarlıyor, ikinci `401`'de `_retriedKey` işaretli olduğu
      // için hata buraya olduğu gibi ulaşıyor — oturum kapanmıyor,
      // kullanıcı ekranda kalıyor ve sunucunun mesajını görüyor. Oturumun
      // gerçekten kapandığı tek durum yenilemenin de başarısız olması, ki o
      // zaman oturum zaten ölmüş demektir. Bu yüzden yolun interceptor'dan
      // muaf tutulması gerekmiyor.
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }
}
