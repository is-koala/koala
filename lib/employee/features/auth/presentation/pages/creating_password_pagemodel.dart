part of 'creating_password_page.dart';

abstract class CreatingPasswordPagemodel extends State<CreatingPasswordPage> {
  bool isVisiblePassword = false;
  bool isVisibleConfirmPassword = false;

  /// Kayıt tipi seçiminde yazılan bayrak. İş veren, şifreden sonra bir de
  /// şirket bilgileri adımına gidiyor; çalışan doğrudan uygulamaya giriyor.
  bool isBusiness = false;

  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool get passwordsMatch =>
      passwordController.text == confirmPasswordController.text &&
      passwordController.text.isNotEmpty;

  bool get isPasswordStrong {
    final password = passwordController.text;
    return password.length >= 8 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]'));
  }

  @override
  void initState() {
    super.initState();
    _loadBusinessStatus();
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      isBusiness = prefs.getBool('isBusiness') ?? false;
    });
  }

  Future<void> onSubmit() async {
    if (!isPasswordStrong || !passwordsMatch) {
      _showValidationWarning();
      return;
    }

    if (isBusiness) {
      context.push(
        '/auth/register-type/register/creating-password/company-informations',
      );
      return;
    }

    // TODO(backend): Şifre gerçek servise gönderilecek; şimdilik yalnızca
    // oturum bayrağı yazılıyor.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);

    if (mounted) {
      context.go('/explore');
    }
  }

  void _showValidationWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !isPasswordStrong
              ? 'Lütfen güçlü bir şifre oluşturun'
              : 'Şifreler eşleşmiyor',
        ),
        backgroundColor: AppColors.primarySoft,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
