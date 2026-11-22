part of 'identity_verification_page.dart';

abstract class IdentityVerificationPagemodel
    extends State<IdentityVerificationPage> {
  late final UserService _userService;
  late final ChipReader _chipReader;

  /// Elle beyanın taslağı; çip okunduğunda dokunulmuyor, okuma kalkınca geri
  /// gelir.
  late final TextEditingController firstName;
  late final TextEditingController lastName;
  late final TextEditingController tcIdentity;
  late final TextEditingController tcDocument;

  DateTime? birthDate;
  bool isSubmitting = false;

  /// `false` iken karar bekleniyor ya da fotoğraf akışı açık.
  bool isReady = false;

  /// Fotoğraf kartı uyarı olarak çizilir.
  bool chipFailed = false;

  /// Çip kanıtı ve sahibi; `null` ise beyan formu. Beş alan ayrıca saklanmıyor:
  /// `chip = null` ikisini birden bırakır, ayrışamaz.
  IdentityChipResult? chip;

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService();
    _chipReader = widget.chipReader ?? ChipReader();
    // Kayıttaki ad çoğu kullanıcıda kimliktekiyle aynı.
    firstName = TextEditingController(text: widget.user.firstName);
    lastName = TextEditingController(text: widget.user.lastName);
    tcIdentity = TextEditingController();
    tcDocument = TextEditingController();
    birthDate = widget.user.birthDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) enter();
    });
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    tcIdentity.dispose();
    tcDocument.dispose();
    super.dispose();
  }

  /// Gösterilen ve gönderilen beyan, **tek kaynak**: çip varsa
  /// [ChipDeclaration], yoksa [ManualDeclaration].
  IdentityDeclaration get declaration {
    return switch (chip) {
      null => ManualDeclaration(
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        tcIdentityNumber: tcIdentity.text.trim(),
        tcDocumentNumber: tcDocument.text.trim(),
        birthDate: birthDate,
      ),
      final read => ChipDeclaration(read),
    };
  }

  bool get canSubmit => declaration.isComplete;

  // ------------------------------------------------------------------ Giriş

  /// Yolu seçer. Doğrudan fotoğraf akışı: bekleyen/onaylı inceleme, iOS ya da
  /// NFC yok; akış kapanınca bu ekran aynı sonuçla kapanır. **Reddedilen**
  /// inceleme çip yolunu kapatmaz. Durum okunamazsa "yok" sayılır, form açılır.
  Future<void> enter() async {
    final provider = context.read<IdentityReviewProvider>();
    await provider.load(silent: true);
    if (!mounted) return;

    final review = provider.review;
    final reviewSettled =
        review != null && (review.isPending || review.isApproved);
    final chipPossible = await _chipPossible();
    if (!mounted) return;

    if (reviewSettled || widget.user.identityVerified || !chipPossible) {
      final result = await context.push<bool>(
        '/identity-documents',
        extra: widget.user,
      );
      if (mounted) context.pop(result ?? false);
      return;
    }

    setState(() => isReady = true);
  }

  /// iOS'ta hayır (NFC yetkisi bu sürümde yok); Android'de donanım yoksa hayır,
  /// kapalıysa evet.
  Future<bool> _chipPossible() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) return false;
    final availability = await _chipReader.availability();
    return availability != NfcAvailability.unsupported;
  }

  /// Bekleyen inceleme varsa ya da akış `true` ile kapandıysa bu ekran da
  /// kapanır; hiçbir şey yapılmadıysa form kalır.
  Future<void> openPhotos() async {
    final provider = context.read<IdentityReviewProvider>();
    final result = await context.push<bool>(
      '/identity-documents',
      extra: widget.user,
    );
    if (!mounted) return;

    if (result == true || (provider.review?.isPending ?? false)) {
      context.pop(result ?? false);
    }
  }

  IdentityReview? get rejectedReview {
    final review = context.read<IdentityReviewProvider>().review;
    return (review?.isRejected ?? false) ? review : null;
  }

  // ------------------------------------------------------------------- Çip

  /// Çip ekranını açar: kanıt forma yazılır, `photos` fotoğraf akışını açar,
  /// `null`'da bir şey değişmez; geçerli okuma boşuna atılmaz.
  Future<void> readChip() async {
    final result = await context.push<Object>('/identity-chip');
    if (!mounted) return;

    switch (result) {
      case IdentityChipResult read:
        setState(() {
          chip = read;
          chipFailed = false;
        });
      case IdentityChipHandoff.photos:
        await openPhotos();
      default:
        break;
    }
  }

  /// Okumayı bırakır: kanıt ve beş alan **tek geçişte** gider. Kullanıcının
  /// "Okumayı Kaldır"ı ve `IDENTITY_CHALLENGE_INVALID` aynı yoldan geçer;
  /// geçersiz kanıtın türevleri kilitli beyan gibi kalmasın.
  void removeChip() => setState(() => chip = null);

  // --------------------------------------------------------------- Gönderim

  Future<void> submit() async {
    // Gövde ekrandaki beyandan kurulur.
    final declaration = this.declaration;
    final birthDate = declaration.birthDate;
    if (birthDate == null) return;

    setState(() => isSubmitting = true);

    try {
      await _userService.verifyIdentity(
        firstName: declaration.firstName,
        lastName: declaration.lastName,
        birthDate: birthDate,
        tcIdentityNumber: declaration.tcIdentityNumber,
        tcDocumentNumber: declaration.tcDocumentNumber,
        evidence: declaration.evidence,
      );

      if (!mounted) return;
      // Başvuru kapısı `/users/me`'ye bakıyor; tazelenmeden dönülmemeli.
      await context.read<UserProvider>().load(silent: true);

      if (!mounted) return;
      AppToast.success(context, 'Kimliğin doğrulandı');
      context.pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showFailure(error);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  /// Tanınan `IDENTITY_*` kodunda bizim karşılık, tanınmayanda sunucunun
  /// mesajı. Her durumda fotoğraf kartı uyarı olur ki aynı okuma döngüye
  /// girmesin.
  void _showFailure(ApiException error) {
    final known = IdentityError.fromErrorCode(error.errorCode);
    AppToast.error(context, known?.message ?? error.message);
    setState(() => chipFailed = true);

    if (known == null) return;

    // Süresi dolmuş sayıyla kanıt bütünüyle geçersiz ve baştan okunmalı;
    // kullanıcı eylemi olmayan tek dönüş yolu, [removeChip] ile aynı geçiş.
    // Yalnız bu kodda: imza ya da makam hatası kanıtı geçersiz kılmıyor.
    if (known.needsFreshChallenge) removeChip();
  }
}
