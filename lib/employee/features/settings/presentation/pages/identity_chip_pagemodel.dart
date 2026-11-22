part of 'identity_chip_page.dart';

enum IdentityChipStage { intro, manual, scanning, reading, failure }

abstract class IdentityChipPagemodel extends State<IdentityChipPage> {
  late final UserService _userService;
  late final ChipReader _reader;
  MrzCameraSession? _liveCamera;

  final TextEditingController documentNumber = TextEditingController();

  static const int earliestYear = 1920;

  /// Kart en çok on yıllık; seçiciyi daha ileri açmak yanlış seçime davet.
  static const int expiryHorizonYears = 15;

  IdentityChipStage stage = IdentityChipStage.intro;

  /// Kart okunmadan **önce** alınır; çipe imzalatılacak şey bu.
  String? challenge;

  bool isPreparing = true;

  DateTime? birthDate;
  DateTime? expiryDate;

  ChipReadFailure? failure;
  ChipReadStep? readStep;

  MrzCameraSession get liveCamera =>
      _liveCamera ??= widget.mrzCamera ?? DeviceMrzCameraSession();

  IdentityChipStage _retryStage = IdentityChipStage.intro;

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService();
    _reader = widget.chipReader ?? ChipReader();
    _prepare();
  }

  @override
  void dispose() {
    documentNumber.dispose();
    super.dispose();
  }

  bool get canReadManually =>
      documentNumber.text.trim().isNotEmpty &&
      birthDate != null &&
      expiryDate != null;

  /// NFC yoksa sunucudan boşuna sayı istenmez: tek kullanımlık ve on dakikalık.
  Future<void> _prepare() async {
    final availability = await _reader.availability();

    if (!mounted) return;
    switch (availability) {
      case NfcAvailability.unsupported:
        _fail(ChipReadFailure.nfcUnsupported);
        return;
      case NfcAvailability.disabled:
        _fail(ChipReadFailure.nfcDisabled);
        return;
      case NfcAvailability.available:
        break;
    }

    try {
      final issued = await _userService.startIdentityChallenge();
      if (!mounted) return;
      setState(() {
        challenge = issued;
        isPreparing = false;
      });
    } on ApiException {
      if (!mounted) return;
      _fail(ChipReadFailure.challengeUnavailable);
    }
  }

  Future<void> scanAndRead() async {
    _retryStage = IdentityChipStage.intro;
    setState(() => stage = IdentityChipStage.scanning);
  }

  void onLiveMrzCaptured(MrzKey key) {
    // Kapatılmış kamera sonraki denemede kullanılmasın.
    _liveCamera = null;
    unawaited(_read(key));
  }

  void onLiveMrzFailure(ChipReadFailure reason) {
    _liveCamera = null;
    _fail(reason);
  }

  Future<void> readManually() async {
    _retryStage = IdentityChipStage.manual;

    await _read(
      MrzKey.manual(
        documentNumber: documentNumber.text,
        birthDate: birthDate!,
        expiryDate: expiryDate!,
      ),
    );
  }

  Future<void> _read(MrzKey key) async {
    final issued = challenge;
    if (issued == null) {
      _fail(ChipReadFailure.challengeUnavailable);
      return;
    }

    setState(() {
      stage = IdentityChipStage.reading;
      readStep = ChipReadStep.waitingForCard;
    });

    try {
      final evidence = await _reader.read(
        key: key,
        challenge: issued,
        onStep: (step) {
          if (mounted) setState(() => readStep = step);
        },
      );

      if (!mounted) return;

      // DG1 kimlik bilgisi vermiyorsa sonuç yok: sunucu da reddederdi.
      final result = IdentityChipResult.parse(evidence);
      if (result == null) {
        _fail(ChipReadFailure.holderUnreadable);
        return;
      }
      context.pop(result);
    } on ChipReadException catch (error) {
      if (!mounted) return;
      _fail(error.reason);
    }
  }

  void _fail(ChipReadFailure reason) {
    setState(() {
      failure = reason;
      stage = IdentityChipStage.failure;
      isPreparing = false;
      readStep = null;
    });
  }

  void retry() {
    setState(() {
      failure = null;
      stage = _retryStage;
    });

    // NFC açılıp dönüldüyse challenge alınmamış olabilir; hazırlık baştan.
    if (challenge == null) {
      setState(() => isPreparing = true);
      unawaited(_prepare());
    }
  }

  void openManualEntry() {
    _liveCamera = null;
    setState(() {
      failure = null;
      stage = IdentityChipStage.manual;
    });
  }

  /// Kimlik ekranı beyan formuyla devam eder; NFC'nin başarısızlığı akış dışına
  /// atmamalı.
  void abandon() => context.pop();

  void continueWithPhotos() => context.pop(IdentityChipHandoff.photos);

  Future<void> pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(earliestYear),
      lastDate: now,
    );
    if (picked == null) return;

    setState(() => birthDate = picked);
  }

  Future<void> pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: expiryDate ?? now,
      // Süresi dolmuş kart da okunabiliyor.
      firstDate: DateTime(earliestYear),
      lastDate: DateTime(now.year + expiryHorizonYears),
    );
    if (picked == null) return;

    setState(() => expiryDate = picked);
  }
}
