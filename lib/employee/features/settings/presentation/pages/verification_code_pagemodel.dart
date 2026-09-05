part of 'verification_code_page.dart';

abstract class VerificationCodePagemodel extends State<VerificationCodePage> {
  /// Sunucunun ürettiği kod tam 6 hane
  /// (`100000 + SECURE_RANDOM.nextInt(900000)`).
  static const int codeLength = 6;

  /// Kodun sunucudaki ömrü. `VerificationInfoDto` `expiresAt` döndürmediği
  /// için sayaç ekranın açıldığı andan başlıyor; gösterilen süre yaklaşık.
  static const Duration codeLifetime = Duration(minutes: 15);

  /// Tekrar gönderme düğmesinin soğuma süresi. Sunucunun ayrı bir tekrar
  /// gönderme ucu yok, düğme `PATCH /users/me`'yi tekrarlıyor; arka arkaya
  /// basılırsa kullanıcıya art arda SMS giderdi.
  static const Duration resendCooldown = Duration(seconds: 60);

  final TextEditingController code = TextEditingController();

  /// Onaylanacak doğrulama. Tekrar gönderim yeni bir kayıt ürettiği için
  /// `widget.verification` değil bu alan esas alınıyor.
  late PendingVerification verification;

  bool isConfirming = false;

  /// Kalan saniyeler saat okunarak değil saniyede bir azaltılarak tutuluyor.
  /// `DateTime.now()`'a bağlamak sayacı test edilemez hâle getirirdi ve
  /// sunucu `expiresAt` döndürmediği için zaten mutlak bir an yok.
  int _codeSecondsLeft = codeLifetime.inSeconds;
  int _resendSecondsLeft = resendCooldown.inSeconds;

  Timer? _ticker;

  VerificationService get _verificationService =>
      widget.verificationService ?? VerificationService();

  @override
  void initState() {
    super.initState();
    verification = widget.verification;
    // Ekran, kod yeni gönderilmişken açılıyor: soğuma süresi de kodun ömrü
    // de o andan başlıyor.
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    code.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_codeSecondsLeft > 0) _codeSecondsLeft--;
        if (_resendSecondsLeft > 0) _resendSecondsLeft--;
      });
      // Sayacak bir şey kalmadıysa boşuna kare çizdirmeye gerek yok.
      if (_codeSecondsLeft == 0 && _resendSecondsLeft == 0) timer.cancel();
    });
  }

  /// Kodun tahmini ömründen kalan süre bitti mi.
  bool get hasTimeLeft => _codeSecondsLeft > 0;

  /// Kalan süre `dd:ss` biçiminde.
  String get remainingLabel {
    final minutes = (_codeSecondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_codeSecondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Soğuma süresinden kalan saniye.
  int get resendCooldownSeconds => _resendSecondsLeft;

  /// Soğuma süresi ancak istek dönünce kuruluyor. Bu bayrak olmadan istek
  /// havadayken düğme açık kalır ve ikinci dokunuş ikinci bir `PATCH` — yani
  /// kullanıcıya ikinci bir SMS — gönderirdi.
  bool _isResending = false;

  bool get canResend =>
      !isConfirming && !_isResending && _resendSecondsLeft == 0;

  /// Girilen kodu onaylar.
  Future<void> confirm() async {
    final token = code.text.trim();
    if (token.length != codeLength) {
      AppToast.error(context, 'Doğrulama kodu $codeLength haneli olmalı.');
      return;
    }

    setState(() => isConfirming = true);
    try {
      await _verificationService.confirm(verification.id, token);
      if (!mounted) return;

      // Yeni e-posta/telefon bu noktada uygulandı; hesap ekranının değeri
      // görebilmesi için kullanıcı tazeleniyor.
      await context.read<UserProvider>().load(silent: true);
      if (!mounted) return;

      AppToast.success(
        context,
        verification.isEmail
            ? 'E-posta adresin doğrulandı.'
            : 'Telefon numaran doğrulandı.',
      );
      _finish(true);
    } on ApiException catch (error) {
      if (!mounted) return;

      // `403` başkasının kaydı, `404` hiç olmayan kayıt. İkisinde de kod
      // girmenin anlamı kalmadı; kullanıcı değişikliği baştan başlatmalı.
      // Tek toast gösteriliyor: [AppToast.show] sıradakini beklemeden
      // öncekini gizlediği için iki mesaj üst üste yazmanın anlamı yok.
      if (error.statusCode == 403 || error.statusCode == 404) {
        AppToast.error(
          context,
          'Bu doğrulama artık geçerli değil. Değişikliği baştan yap.',
        );
        _finish(false);
        return;
      }

      // Kod hatalı ya da süresi dolmuş: sunucunun mesajı gösteriliyor,
      // kullanıcı ekranda kalıyor ve yeniden deniyor.
      AppToast.error(context, error.message);
      code.clear();
    } finally {
      if (mounted) setState(() => isConfirming = false);
    }
  }

  /// Kodu yeniden göndertir.
  ///
  /// Sunucunun tekrar gönderme ucu yok: aynı yeni değerle `PATCH /users/me`
  /// çağrıldığında doğrulanmamış eski kayıt siliniyor ve yeni bir kod
  /// üretiliyor. Dönen yeni kimlik eskisinin yerine geçmeli, yoksa kullanıcı
  /// yeni kodu eski kayda göndermeye çalışır.
  Future<void> resend() async {
    if (_isResending) return;

    final target = verification.sentTo;
    if (target == null || target.isEmpty) {
      AppToast.error(context, 'Kod yeniden gönderilemedi.');
      return;
    }

    setState(() => _isResending = true);
    final provider = context.read<UserProvider>();
    try {
      final pending = await provider.updateProfile(
        email: verification.isEmail ? target : null,
        phoneNumber: verification.isEmail ? null : target,
      );
      if (!mounted) return;

      if (pending == null) {
        AppToast.error(context, provider.errorMessage ?? 'Kod gönderilemedi.');
        return;
      }

      final refreshed = pending.where((item) => item.type == verification.type);

      setState(() {
        if (refreshed.isNotEmpty) verification = refreshed.first;
        _codeSecondsLeft = codeLifetime.inSeconds;
        _resendSecondsLeft = resendCooldown.inSeconds;
        code.clear();
      });
      // Sayaç bitmişse durmuş olabilir; yeni kodun süresi için tekrar
      // kuruluyor.
      _startTicker();

      AppToast.success(context, 'Yeni kod gönderildi.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _finish(bool verified) {
    final onFinished = widget.onFinished;
    if (onFinished != null) {
      onFinished(verified);
    } else {
      context.pop(verified);
    }
  }
}
