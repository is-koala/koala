part of 'verification_code_page.dart';

abstract class VerificationCodePagemodel extends State<VerificationCodePage> {
  /// Sunucunun ürettiği kod tam 6 hane
  /// (`100000 + SECURE_RANDOM.nextInt(900000)`).
  static const int codeLength = 6;

  /// Eski sunucu sürümü son kullanma anını döndürmezse kullanılan yaklaşık
  /// kod ömrü.
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

  /// Sunucunun mutlak son kullanma anı; eski sunucuda ekran açılışından
  /// itibaren [codeLifetime] sonrası kullanılır.
  late DateTime _codeDeadline;
  int _resendSecondsLeft = resendCooldown.inSeconds;

  Timer? _ticker;

  VerificationService get _verificationService =>
      widget.verificationService ?? VerificationService();

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  DateTime _deadlineFor(PendingVerification value) =>
      value.expiresAt ?? _now().add(codeLifetime);

  @override
  void initState() {
    super.initState();
    verification = widget.verification;
    _codeDeadline = _deadlineFor(verification);
    // Ekran kod yeni gönderilmişken açıldığı için soğuma süresi o andan
    // başlıyor.
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
        if (_resendSecondsLeft > 0) _resendSecondsLeft--;
      });
      // Sayacak bir şey kalmadıysa boşuna kare çizdirmeye gerek yok.
      if (_codeSecondsLeft == 0 && _resendSecondsLeft == 0) timer.cancel();
    });
  }

  int get _codeSecondsLeft {
    final microseconds = _codeDeadline.difference(_now()).inMicroseconds;
    if (microseconds <= 0) return 0;
    return (microseconds + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
  }

  /// Kodun sunucunun bildirdiği veya geriye uyumlu tahmini ömrü kaldı mı.
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

      // `forbidden` başkasının kaydı, `notFound` hiç olmayan kayıt. İkisinde
      // de kod girmenin anlamı kalmadı; kullanıcı değişikliği baştan
      // başlatmalı.
      //
      // Tipe bakılıyor, `statusCode`'a değil: ayrımın kaynağı sunucunun
      // `errorCategory` alanı (`ACCESS_DENIED`, `RESOURCE_NOT_FOUND`),
      // `403`/`404` yalnızca kategori gelmediğinde devreye giren yedek
      // (is-koala/koala#86).
      //
      // Tek toast gösteriliyor: [AppToast.show] sıradakini beklemeden
      // öncekini gizlediği için iki mesaj üst üste yazmanın anlamı yok.
      if (error.type == ApiErrorType.forbidden ||
          error.type == ApiErrorType.notFound) {
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
        // Soğuma hata yolunda da kuruluyor. İstemcide zaman aşımına uğrayan
        // ya da `500` dönen bir `PATCH` sunucuda işlenmiş ve kod gönderilmiş
        // olabilir; düğmeyi aynı karede yeniden açmak, kullanıcının arka
        // arkaya basıp pes peşe SMS ürettirmesine izin verirdi. Soğumanın
        // varlık sebebi zaten tam olarak bu.
        _armResendCooldown();
        AppToast.error(context, provider.errorMessage ?? 'Kod gönderilemedi.');
        return;
      }

      final refreshed = pending.where((item) => item.type == verification.type);
      if (refreshed.isEmpty) {
        // Boş liste tek bir anlama geliyor: `UserManager.patchCurrentUser`
        // gönderilen değer kullanıcının mevcut değerine eşitse doğrulama
        // açmadan `200` dönüyor. Yani bekleyen doğrulama bu arada (örneğin
        // başka bir cihazda) tamamlanmış ve değer uygulanmış. Kod istemenin
        // anlamı kalmadı; "yeni kod gönderildi" demek kullanıcıyı hiç
        // gelmeyecek bir kod için bekletirdi.
        //
        // Çıkış `true` ile: değer gerçekten yazıldı ve `updateProfile`
        // sağlayıcıdaki kullanıcıyı zaten tazeledi. `false` dönmek çağıranın
        // doğrulama zincirini keserdi (`verified != true` → `break`), yani
        // aynı kaydetmede bekleyen ikinci doğrulama hiç sorulmazdı.
        AppToast.success(
          context,
          verification.isEmail
              ? 'E-posta adresin zaten doğrulanmış.'
              : 'Telefon numaran zaten doğrulanmış.',
        );
        _finish(true);
        return;
      }

      setState(() {
        verification = refreshed.first;
        _codeDeadline = _deadlineFor(verification);
        code.clear();
      });
      _armResendCooldown();

      AppToast.success(context, 'Yeni kod gönderildi.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  /// Soğuma süresini baştan kurar.
  ///
  /// Sayaç sıfıra inince kendini durduruyor; süre yeniden kurulduğunda
  /// tıklama da yeniden başlatılmalı, yoksa kalan saniye hiç azalmaz ve
  /// düğme bir daha açılmaz.
  void _armResendCooldown() {
    setState(() => _resendSecondsLeft = resendCooldown.inSeconds);
    _startTicker();
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
