part of 'login_page.dart';

abstract class LoginPagemodel extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool isPasswordHidden = true;

  /// İstek sürerken buton yükleniyor durumuna geçiyor ve tekrar basılamıyor.
  bool isSubmitting = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> onLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      AppToast.error(context, 'E-posta ve şifreni gir.');
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final user = await _authService.login(email: email, password: password);
      if (!mounted) return;

      context.go(_destinationFor(user));
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  /// Kullanıcı tipine göre açılacak arayüz.
  ///
  /// [AuthService.login] kullanıcı bilgisini alamazsa `null` dönüyor; o
  /// durumda oturum açık kalıyor ama kullanıcı çalışan arayüzünde başlıyor.
  String _destinationFor(CurrentUser? user) {
    return user?.isEmployer == true ? '/business/home' : '/explore';
  }
}
