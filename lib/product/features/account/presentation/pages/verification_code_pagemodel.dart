part of 'verification_code_page.dart';

abstract class VerificationCodePagemodel extends State<VerificationCodePage> {
  static const int codeLength = 6;

  /// Eski sunucu son kullanma anını döndürmezse.
  static const Duration codeLifetime = Duration(minutes: 15);

  /// Düğme `PATCH`'i tekrarlıyor; arka arkaya basmak art arda SMS gönderirdi.
  static const Duration resendCooldown = Duration(seconds: 60);

  final TextEditingController code = TextEditingController();

  /// Tekrar gönderim yeni kayıt ürettiği için `widget.verification` değil bu.
  late PendingVerification verification;

  bool isConfirming = false;

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
    // Kod yeni gönderilmiş olduğu için soğuma şimdi başlıyor.
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
      if (_codeSecondsLeft == 0 && _resendSecondsLeft == 0) timer.cancel();
    });
  }

  int get _codeSecondsLeft {
    final microseconds = _codeDeadline.difference(_now()).inMicroseconds;
    if (microseconds <= 0) return 0;
    return (microseconds + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
  }

  bool get hasTimeLeft => _codeSecondsLeft > 0;

  String get remainingLabel {
    final minutes = (_codeSecondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_codeSecondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  int get resendCooldownSeconds => _resendSecondsLeft;

  /// Soğuma istek dönünce kuruluyor; bu bayrak olmadan ikinci dokunuş ikinci
  /// SMS gönderirdi.
  bool _isResending = false;

  bool get canResend =>
      !isConfirming && !_isResending && _resendSecondsLeft == 0;

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

      await context.read<UserProvider>().load(silent: true);
      if (!mounted) return;

      AppToast.success(
        context,
        verification.isEmail
            ? 'E-posta adresiniz doğrulandı.'
            : 'Telefon numaranız doğrulandı.',
      );
      _finish(true);
    } on ApiException catch (error) {
      if (!mounted) return;

      // Başkasının ya da olmayan kayıt: kod girmenin anlamı kalmadı, kullanıcı
      // baştan başlamalı. Tipe bakılıyor, durum koduna değil (#86).
      if (error.type == ApiErrorType.forbidden ||
          error.type == ApiErrorType.notFound) {
        AppToast.error(
          context,
          'Bu doğrulama artık geçerli değil. Değişikliği baştan yapın.',
        );
        _finish(false);
        return;
      }

      // Hatalı ya da süresi dolmuş kod: kullanıcı yeniden dener.
      AppToast.error(context, error.message);
      code.clear();
    } finally {
      if (mounted) setState(() => isConfirming = false);
    }
  }

  /// Kodu yeniden göndertir: aynı değerle `PATCH` yeni kod üretir. Dönen yeni
  /// kimlik eskisinin yerine geçmeli.
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
        // Hatada da kuruluyor: zaman aşımına uğrayan `PATCH` sunucuda işlenmiş
        // ve SMS gitmiş olabilir.
        _armResendCooldown();
        AppToast.error(context, provider.errorMessage ?? 'Kod gönderilemedi.');
        return;
      }

      final refreshed = pending.where((item) => item.type == verification.type);
      if (refreshed.isEmpty) {
        // Boş liste: değer bu arada başka yerde doğrulanıp uygulanmış. "Yeni
        // kod gönderildi" demek kullanıcıyı boşuna bekletirdi. `true` ile
        // çıkılıyor ki çağıranın doğrulama zinciri kesilmesin.
        AppToast.success(
          context,
          verification.isEmail
              ? 'E-posta adresiniz zaten doğrulanmış.'
              : 'Telefon numaranız zaten doğrulanmış.',
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

  /// Sayaç sıfırda kendini durdurduğu için yeniden başlatılmalı.
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
