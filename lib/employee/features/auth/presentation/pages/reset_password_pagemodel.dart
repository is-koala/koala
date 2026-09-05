part of 'reset_password_page.dart';

abstract class ResetPasswordPagemodel extends State<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _isSaving = false;

  AuthService get _authService => widget.authService ?? AuthService();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text;
    if (!PasswordRule.isSatisfiedBy(password)) {
      AppToast.error(context, PasswordRule.requirement);
      return;
    }
    if (password != _confirmation.text) {
      AppToast.error(context, 'Şifreler eşleşmiyor.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _authService.resetPassword(
        resetToken: widget.token,
        newPassword: password,
      );
      if (!mounted) return;
      AppToast.success(
        context,
        'Şifren güncellendi. Şimdi giriş yapabilirsin.',
      );
      final onCompleted = widget.onCompleted;
      if (onCompleted != null) {
        onCompleted();
      } else {
        context.go('/auth/login');
      }
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
