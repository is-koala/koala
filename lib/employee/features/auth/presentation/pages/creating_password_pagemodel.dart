part of 'creating_password_page.dart';

abstract class CreatingPasswordPagemodel extends State<CreatingPasswordPage> {
  bool isPasswordHidden = true;
  bool isConfirmPasswordHidden = true;

  /// İşveren şifreden sonra şirket bilgilerine gider. Kaynak token yanıtı;
  /// yoksa kayıt tipi ekranının yerel bayrağı.
  bool isBusiness = false;

  bool isPreparing = false;

  String? preparationError;

  List<AgreementVersion> agreements = const [];

  final Map<String, bool> consents = {};

  String? _setPasswordToken;

  bool isSubmitting = false;

  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  late final AuthService _authService = widget.authService ?? AuthService();
  late final LegalService _legalService = widget.legalService ?? LegalService();

  bool get passwordsMatch =>
      passwordController.text == confirmPasswordController.text &&
      passwordController.text.isNotEmpty;

  bool get isPasswordStrong =>
      PasswordRule.isSatisfiedBy(passwordController.text);

  /// Backend eksik onayla kaydı reddediyor.
  bool get areMandatoryConsentsGranted {
    return agreements
        .where((agreement) => agreement.mandatory)
        .every((agreement) => consents[agreement.id] == true);
  }

  bool get canSubmit =>
      _setPasswordToken != null && areMandatoryConsentsGranted;

  @override
  void initState() {
    super.initState();
    bootstrap();
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  /// Token doğrulama ve sözleşmeler paralel; ikisi de zorunlu.
  Future<void> bootstrap() async {
    setState(() {
      isPreparing = true;
      preparationError = null;
    });

    await Future.wait([_resolveToken(), _loadAgreements()]);

    if (!mounted) return;
    setState(() => isPreparing = false);
  }

  Future<void> _resolveToken() async {
    final token = widget.token;

    if (token == null) {
      final prefs = await SharedPreferences.getInstance();
      isBusiness = prefs.getBool('isBusiness') ?? false;
      preparationError =
          'Doğrulama bağlantısı bulunamadı. Lütfen e-postandaki linke tıkla.';
      return;
    }

    try {
      final verification = await _authService.verifyRegistrationToken(token);
      _setPasswordToken = verification.setPasswordToken;
      isBusiness = verification.isEmployer;
    } on ApiException catch (error) {
      preparationError = error.message;
    }
  }

  /// Alınamazsa kayıt tamamlanamaz: zorunlu onaylar bilinmiyor.
  Future<void> _loadAgreements() async {
    try {
      final current = await _legalService.fetchCurrentAgreements();
      agreements = current;
      consents
        ..clear()
        ..addEntries(current.map((agreement) => MapEntry(agreement.id, false)));
    } on ApiException catch (error) {
      preparationError ??= error.message;
    }
  }

  void toggleConsent(String agreementId, bool isGranted) {
    setState(() => consents[agreementId] = isGranted);
  }

  Future<void> onSubmit() async {
    if (!isPasswordStrong || !passwordsMatch) {
      _showValidationWarning();
      return;
    }

    final setPasswordToken = _setPasswordToken;
    if (setPasswordToken == null) {
      AppToast.error(
        context,
        'Doğrulama bağlantısı geçersiz. Lütfen kaydı yeniden başlat.',
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await _authService.completeRegistration(
        setPasswordToken: setPasswordToken,
        password: passwordController.text,
        isEmployer: isBusiness,
        consents: consents.entries
            .map(
              (entry) => ConsentDecision(
                agreementVersionId: entry.key,
                granted: entry.value,
              ),
            )
            .toList(),
      );

      if (!mounted) return;

      // Hesap oluştu ve oturum açık; işveren bireysel ya da şirket yolunu
      // seçer.
      context.go(isBusiness ? RegistrationRoutes.employerType : '/explore');
    } on ApiException catch (error) {
      if (!mounted) return;

      // Kayıt ilk çağrıda tamamlanmış olabilir (ikinci `404`); oturum açıksa
      // hesap oluşmuştur, hata göstermek başarıyı başarısız gösterir.
      if (SessionManager().isLoggedIn) {
        context.go(isBusiness ? RegistrationRoutes.employerType : '/explore');
        return;
      }

      AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void _showValidationWarning() {
    AppToast.error(
      context,
      !isPasswordStrong
          ? 'Lütfen güçlü bir şifre oluşturun'
          : 'Şifreler eşleşmiyor',
    );
  }
}
