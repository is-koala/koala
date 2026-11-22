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

  /// Doğrulayıp parolayı değiştirir; kurallar ağ turu beklemeden istemcide.
  Future<void> submit() async {
    final current = currentPassword.text;
    final next = newPassword.text;
    final repeated = confirmation.text;

    if (current.isEmpty || next.isEmpty || repeated.isEmpty) {
      AppToast.error(context, 'Bütün alanları doldurun.');
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
      AppToast.error(
        context,
        'Yeni şifreniz mevcut şifrenizden farklı olmalı.',
      );
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

      // Bu cihazın oturumu açık kalıyor; yeniden giriş istenmez.
      AppToast.success(
        context,
        'Şifreniz güncellendi. Diğer cihazlardaki oturumlarınız kapatıldı.',
      );

      final onCompleted = widget.onCompleted;
      if (onCompleted != null) {
        onCompleted();
      } else {
        context.pop();
      }
    } on ApiException catch (error) {
      // Yanlış mevcut parolada sunucu `400` döndürüyor. `401` gelse de
      // `AuthInterceptor` bir kez tazeleyip hatayı buraya bırakıyor; oturum
      // yalnız yenileme de düşerse kapanır.
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }
}
