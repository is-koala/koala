part of 'register_page.dart';

abstract class RegisterPagemodel extends State<RegisterPage> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  final AuthService _authService = AuthService();

  bool isSubmitting = false;

  /// Sunucuya boş yere gitmemek için kullanılan kaba e-posta kontrolü.
  /// Asıl doğrulamayı backend `@Email` ile yapıyor.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> onRegister() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
      AuthSnackbar.show(context, 'Lütfen tüm alanları doldur.', isError: true);
      return;
    }

    if (!_emailPattern.hasMatch(email)) {
      AuthSnackbar.show(
        context,
        'Geçerli bir e-posta adresi gir.',
        isError: true,
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await _authService.startRegistration(
        firstName: firstName,
        lastName: lastName,
        email: email,
        isEmployer: widget.isBusiness,
      );

      if (!mounted) return;

      // Adres zaten kayıtlıysa da backend 200 dönüyor (hesabın varlığını
      // sızdırmamak için), o yüzden her durumda bekleme ekranına geçiliyor.
      context.go(
        '/auth/register-type/register/email-verification-pending'
        '?isBusiness=${widget.isBusiness}&email=${Uri.encodeQueryComponent(email)}',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      AuthSnackbar.show(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }
}
