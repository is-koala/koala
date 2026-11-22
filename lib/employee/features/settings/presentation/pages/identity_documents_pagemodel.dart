part of 'identity_documents_page.dart';

enum IdentityDocumentsStage {
  loading,

  loadFailed,

  form,

  uploading,

  pending,

  approved,
}

class IdentityDocumentsFailure {
  const IdentityDocumentsFailure(this.message, {this.showSupport = false});

  final String message;

  final bool showSupport;
}

abstract class IdentityDocumentsPagemodel extends State<IdentityDocumentsPage> {
  late final IdentityDocumentService _service;
  late final IdentityPhotoPicker _picker;

  late final TextEditingController firstName;
  late final TextEditingController lastName;
  late final TextEditingController tcIdentity;
  late final TextEditingController tcDocument;

  DateTime? birthDate;

  final Map<IdentityPhotoSlot, IdentityPhoto> photos = {};

  IdentityDocumentsStage stage = IdentityDocumentsStage.loading;

  IdentityReview? review;

  String? loadError;

  IdentityDocumentsFailure? failure;

  /// Toplam bilinmiyorsa `null`, çubuk belirsiz.
  double? progress;

  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? IdentityDocumentService();
    _picker = widget.picker ?? const IdentityPhotoPicker();
    // Kayıttaki değerler çoğu kullanıcıda kimliktekiyle aynı; yeniden yazdırma.
    firstName = TextEditingController(text: widget.user.firstName);
    lastName = TextEditingController(text: widget.user.lastName);
    tcIdentity = TextEditingController();
    tcDocument = TextEditingController();
    birthDate = widget.user.birthDate;
    // Kuruluşta gelen bildirim "build içinde setState" ile düşürürdü.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
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

  /// Alanlardan **tek kaynak**.
  IdentityDeclaration get declaration => ManualDeclaration(
    firstName: firstName.text.trim(),
    lastName: lastName.text.trim(),
    tcIdentityNumber: tcIdentity.text.trim(),
    tcDocumentNumber: tcDocument.text.trim(),
    birthDate: birthDate,
  );

  bool get canSubmit =>
      stage == IdentityDocumentsStage.form &&
      declaration.isComplete &&
      photos.length == IdentityPhotoSlot.values.length;

  /// Açılışta başlayan okuma sürüyorsa beklenir, bitmişse yeniden sorulur;
  /// durum şimdiki olmalı.
  Future<void> load() async {
    setState(() {
      stage = IdentityDocumentsStage.loading;
      loadError = null;
    });

    final provider = context.read<IdentityReviewProvider>();
    await provider.load(silent: true);
    if (!mounted) return;

    if (!provider.hasLoaded) {
      setState(() {
        loadError = provider.errorMessage;
        stage = IdentityDocumentsStage.loadFailed;
      });
      return;
    }

    _applyReview(provider.review);
  }

  /// Kullanıcı zaten doğrulanmışsa onay görünümü: bayrak son söz.
  void _applyReview(IdentityReview? current) {
    setState(() {
      review = current;
      if (widget.user.identityVerified || (current?.isApproved ?? false)) {
        stage = IdentityDocumentsStage.approved;
      } else if (current?.isPending ?? false) {
        stage = IdentityDocumentsStage.pending;
      } else {
        stage = IdentityDocumentsStage.form;
      }
    });
  }

  // ---------------------------------------------------------------- Kareler

  Future<void> pick(IdentityPhotoSlot slot) async {
    final source = await IdentityPhotoSourceSheet.show(context, slot: slot);
    if (source == null || !mounted) return;

    final candidate = await _picker.pick(slot, source);
    if (candidate == null || !mounted) return;

    final (:photo, :rejection) = IdentityPhotoPolicy.accept(candidate);
    final refused =
        rejection ??
        IdentityPhotoPolicy.checkTotal([
          for (final entry in photos.entries)
            if (entry.key != slot) entry.value,
          photo!,
        ]);
    if (refused != null) {
      AppToast.error(context, refused.message);
      return;
    }

    setState(() {
      photos[slot] = photo!;
      failure = null;
    });
  }

  void remove(IdentityPhotoSlot slot) => setState(() => photos.remove(slot));

  // --------------------------------------------------------------- Gönderim

  Future<void> submit() async {
    final declaration = this.declaration;
    if (!canSubmit) return;

    setState(() {
      stage = IdentityDocumentsStage.uploading;
      failure = null;
      progress = 0;
    });

    try {
      final opened = await _service.submit(
        identity: declaration,
        photos: Map.of(photos),
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() => progress = uploadFraction(sent, total));
        },
      );
      if (!mounted) return;

      context.read<IdentityReviewProvider>().apply(opened);
      AppToast.success(context, 'Belgelerin incelemeye alındı');
      _applyReview(opened);
    } on ApiException catch (error) {
      if (!mounted) return;
      await _handleSubmitFailure(error);
    } finally {
      if (mounted) setState(() => progress = null);
    }
  }

  /// Tanınan kodda bizim metin ve eylem; tanınmayanda sunucunun metni.
  Future<void> _handleSubmitFailure(ApiException error) async {
    final known = IdentityDocumentError.of(error);

    switch (known?.action) {
      case IdentityDocumentAction.showStatus:
        // Okuma da düşerse form ve mesaj kalır.
        final provider = context.read<IdentityReviewProvider>();
        await provider.load(silent: true);
        if (!mounted) return;
        if (provider.hasLoaded && provider.review != null) {
          _applyReview(provider.review);
          AppToast.info(context, known!.message);
          return;
        }
        _showFailure(known!.message);

      case IdentityDocumentAction.alreadyVerified:
        await context.read<UserProvider>().load(silent: true);
        if (!mounted) return;
        AppToast.success(context, known!.message);
        context.pop(true);

      case IdentityDocumentAction.contactSupport:
        _showFailure(known!.message, showSupport: true);

      case IdentityDocumentAction.reselectPhotos:
      case IdentityDocumentAction.retry:
        _showFailure(known!.message);

      case null:
        _showFailure(error.message);
    }
  }

  void _showFailure(String message, {bool showSupport = false}) {
    setState(() {
      failure = IdentityDocumentsFailure(message, showSupport: showSupport);
      stage = IdentityDocumentsStage.form;
    });
  }

  // ------------------------------------------------------------------ Durum

  Future<void> refreshStatus() async {
    setState(() => isRefreshing = true);
    final provider = context.read<IdentityReviewProvider>();
    await provider.load(silent: true);
    if (!mounted) return;
    setState(() => isRefreshing = false);

    final message = provider.errorMessage;
    if (message != null && !provider.hasLoaded) {
      AppToast.error(context, message);
      return;
    }
    _applyReview(provider.review);
  }

  /// Doğrulama tamamlanmadı: `false`.
  void leave() => context.pop(false);

  /// `/users/me` tazelenip `true`; çağıran taze bayrağa bakar.
  Future<void> leaveVerified() async {
    await context.read<UserProvider>().load(silent: true);
    if (!mounted) return;
    context.pop(true);
  }
}
