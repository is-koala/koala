part of 'creating_password_page.dart';

abstract class CreatingPasswordPagemodel extends State<CreatingPasswordPage> {
  /// #58: giriş ve şifre değiştir ile aynı; göz düğmesi açar.
  bool isPasswordHidden = true;
  bool isConfirmPasswordHidden = true;

  /// Kayıt tipi. İş veren, şifreden sonra bir de şirket bilgileri adımına
  /// gidiyor; çalışan doğrudan uygulamaya giriyor.
  ///
  /// Kaynağı `/auth/verify-registration-token` yanıtı; token yoksa kayıt tipi
  /// ekranında yazılan yerel bayrağa düşülüyor.
  bool isBusiness = false;

  /// Token doğrulanıp sözleşmeler çekilirken açık kalan yükleniyor durumu.
  bool isPreparing = false;

  /// Hazırlık adımlarından biri başarısız olduysa gösterilecek mesaj.
  String? preparationError;

  /// Onaylanacak sözleşmeler.
  List<AgreementVersion> agreements = const [];

  /// Sözleşme kimliğinden onay durumuna. Kutular buradan çiziliyor.
  final Map<String, bool> consents = {};

  /// `/auth/complete-registration` çağrısına gönderilecek token.
  String? _setPasswordToken;

  bool isSubmitting = false;

  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final AuthService _authService = AuthService();
  final LegalService _legalService = LegalService();

  bool get passwordsMatch =>
      passwordController.text == confirmPasswordController.text &&
      passwordController.text.isNotEmpty;

  bool get isPasswordStrong =>
      PasswordRule.isSatisfiedBy(passwordController.text);

  /// Zorunlu sözleşmelerin hepsi işaretlendi mi. Backend eksik onayla kaydı
  /// reddettiği için buton bu sağlanana kadar pasif duruyor.
  bool get areMandatoryConsentsGranted {
    return agreements
        .where((agreement) => agreement.mandatory)
        .every((agreement) => consents[agreement.id] == true);
  }

  /// Buton basılabilir mi.
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

  /// Ekranın açılabilmesi için gereken iki çağrı: token doğrulama ve
  /// sözleşmeleri çekme. İkisi paralel gidiyor, ikisi de zorunlu.
  Future<void> bootstrap() async {
    setState(() {
      isPreparing = true;
      preparationError = null;
    });

    await Future.wait([_resolveToken(), _loadAgreements()]);

    if (!mounted) return;
    setState(() => isPreparing = false);
  }

  /// E-postadaki bağlantıdan gelen token'ı şifre belirleme token'ına çevirir.
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

  /// Yürürlükteki sözleşmeleri çeker.
  ///
  /// Alınamazsa kayıt tamamlanamaz: hangi onayların zorunlu olduğu
  /// bilinmeden gönderilecek liste kurulamıyor.
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

      // Hesap bu noktada oluştu ve oturum açıldı. İşveren bundan sonra
      // bireysel ilan veya gerçek şirket profili arasında seçim yapar.
      context.go(isBusiness ? RegistrationRoutes.employerType : '/explore');
    } on ApiException catch (error) {
      if (!mounted) return;

      // Kayıt ilk çağrıda tamamlanmış olabilir: bekleyen kayıt tüketildiği
      // için ikinci çağrı `404` döner. Oturum açıksa hesap gerçekten
      // oluşmuştur; kullanıcıya hata göstermek başarılı kaydı başarısız
      // gibi sunar.
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
