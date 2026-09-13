part of 'identity_chip_page.dart';

/// Ekranın hangi adımda olduğu.
enum IdentityChipStage {
  /// Ne yapılacağını anlatan giriş; taramayı ya da elle girişi başlatıyor.
  intro,

  /// MRZ okunamadığında (ya da kullanıcı istediğinde) üç kısa alan.
  manual,

  /// Arka kameradaki MRZ canlı ve kararlı biçimde aranıyor.
  scanning,

  /// Kart okunuyor.
  reading,

  /// Ayrışmış bir hata; ne olduğu ve ne yapılacağı ekranda.
  failure,
}

abstract class IdentityChipPagemodel extends State<IdentityChipPage> {
  late final UserService _userService;
  late final ChipReader _reader;
  MrzCameraSession? _liveCamera;

  final TextEditingController documentNumber = TextEditingController();

  /// Doğum tarihi seçicinin gidebileceği en eski yıl; kimlik ekranındaki
  /// sınırın aynısı.
  static const int earliestYear = 1920;

  /// Kimlik kartının azami geçerlilik ufku. Kart en fazla on yıllık
  /// veriliyor; seçiciyi bundan ileri açmak yalnız yanlış seçime davet.
  static const int expiryHorizonYears = 15;

  IdentityChipStage stage = IdentityChipStage.intro;

  /// Sunucudan alınan tek kullanımlık sayı. Kart okunmadan **önce**
  /// alınıyor: çipe imzalatılacak şey bu.
  String? challenge;

  /// Hazırlık (NFC durumu + challenge) sürüyor mu.
  bool isPreparing = true;

  DateTime? birthDate;
  DateTime? expiryDate;

  ChipReadFailure? failure;
  ChipReadStep? readStep;

  MrzCameraSession get liveCamera =>
      _liveCamera ??= widget.mrzCamera ?? DeviceMrzCameraSession();

  /// Hatadan sonra "Tekrar Dene" kullanıcıyı geldiği adıma döndürsün diye.
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

  /// NFC durumunu okur ve challenge'ı alır.
  ///
  /// Sıra önemli: NFC yoksa sunucudan boşuna sayı istemiyoruz, çünkü sayı
  /// tek kullanımlık ve on dakika sonra çöp oluyor.
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

  /// Kartın arka yüzünü tarar, sonra çipe gider.
  Future<void> scanAndRead() async {
    _retryStage = IdentityChipStage.intro;
    setState(() => stage = IdentityChipStage.scanning);
  }

  void onLiveMrzCaptured(MrzKey key) {
    // Widget sahneden çıkarken kendi oturumunu kapatır; sonraki denemede
    // kapatılmış kamerayı yeniden kullanmamak için referansı bırakıyoruz.
    _liveCamera = null;
    unawaited(_read(key));
  }

  void onLiveMrzFailure(ChipReadFailure reason) {
    _liveCamera = null;
    _fail(reason);
  }

  /// Elle girilen üç alanla çipe gider.
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

      // Formun beş alanı bu sonuçtan okunacak. Kanıt var ama DG1 kimlik
      // bilgisi vermiyorsa sonuç yok: sunucu da reddedecekti ve formu boş
      // bir kanıtla kilitlemek kullanıcıya çıkış bırakmazdı.
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

  /// Hata ekranından geldiği adıma döner.
  void retry() {
    setState(() {
      failure = null;
      stage = _retryStage;
    });

    // NFC kapalıyken kullanıcı ayarlardan açıp döndüyse challenge hiç
    // alınmamış olabilir; hazırlık baştan yürütülüyor.
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

  /// Çip yolunu tümüyle bırakır. Kimlik ekranı beyan formuyla devam ediyor:
  /// NFC'nin başarısızlığı kullanıcıyı akışın dışına atmamalı.
  void abandon() => context.pop();

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
      // Süresi dolmuş kart da okunabiliyor; alt sınır bu yüzden geçmişte.
      firstDate: DateTime(earliestYear),
      lastDate: DateTime(now.year + expiryHorizonYears),
    );
    if (picked == null) return;

    setState(() => expiryDate = picked);
  }
}
