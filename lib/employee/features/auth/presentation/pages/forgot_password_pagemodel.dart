part of 'forgot_password_page.dart';

abstract class ForgotPasswordPagemodel extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _isSending = false;

  AuthService get _authService => widget.authService ?? AuthService();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      AppToast.error(context, 'Geçerli bir e-posta adresi gir.');
      return;
    }

    setState(() => _isSending = true);
    try {
      await _authService.forgotPassword(email);
      if (!mounted) return;
      AppToast.success(
        context,
        'Hesap varsa şifre yenileme bağlantısı e-postana gönderildi.',
      );
      final onSent = widget.onSent;
      if (onSent != null) {
        onSent();
      } else {
        context.pop();
      }
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
