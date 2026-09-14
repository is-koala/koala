part of 'identity_documents_page.dart';

/// Ekranın hangi adımda olduğu.
enum IdentityDocumentsStage {
  /// Son inceleme sunucudan okunuyor.
  loading,

  /// Okunamadı; ne form ne durum çizilebiliyor, kullanıcı tekrar deniyor.
  loadFailed,

  /// Beyan ve dört kare; inceleme yoksa ya da reddedildiyse.
  form,

  /// Tek istek gönderiliyor; ilerleme çiziliyor, düğmeler kapalı.
  uploading,

  /// Personel kuyruğunda bekleyen inceleme.
  pending,

  /// Personel onayladı.
  approved,
}

/// Gönderimin neden reddedildiği; formun üstünde duran kutunun içeriği.
class IdentityDocumentsFailure {
  const IdentityDocumentsFailure(this.message, {this.showSupport = false});

  final String message;

  /// Kullanıcının tek başına çözemeyeceği durumlarda destek adresi de
  /// yazılıyor.
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

  /// Seçilmiş kareler; anahtar kare, dördü de dolunca gönderilebiliyor.
  final Map<IdentityPhotoSlot, IdentityPhoto> photos = {};

  IdentityDocumentsStage stage = IdentityDocumentsStage.loading;

  /// Sunucudaki son inceleme; formun üstündeki red gerekçesi ve bekleme
  /// görünümü buradan.
  IdentityReview? review;

  /// Okuma hatası; yalnız [IdentityDocumentsStage.loadFailed]'da.
  String? loadError;

  /// Son gönderimin hatası; yeni denemede temizleniyor.
  IdentityDocumentsFailure? failure;

  /// Gönderilen payın oranı (0–1); toplam bilinmiyorsa `null` ve çubuk
  /// belirsiz döner.
  double? progress;

  /// Bekleme görünümünde "Durumu Yenile" sürüyor mu.
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? IdentityDocumentService();
    _picker = widget.picker ?? const IdentityPhotoPicker();
    // Kayıttaki ad, soyad ve doğum tarihi çoğu kullanıcıda kimliktekiyle
    // aynı; boş açmak yeniden yazdırmak olurdu.
    firstName = TextEditingController(text: widget.user.firstName);
    lastName = TextEditingController(text: widget.user.lastName);
    tcIdentity = TextEditingController();
    tcDocument = TextEditingController();
    birthDate = widget.user.birthDate;
    // İlk kare çizildikten sonra: provider'ın bildirimi kuruluş sırasında
    // gelirse ağaç "build içinde setState" ile düşüyor.
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

  /// Ekranın gönderdiği beyan; alanlardan **tek kaynak**.
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

  /// Son incelemeyi okuyup ekranı ona göre kurar.
  ///
  /// Provider üzerinden: açılışta başlatılan okuma sürüyorsa aynı yanıt
  /// bekleniyor, bitmişse yeniden soruluyor — kullanıcı bu ekranı açtığında
  /// durum dakikalar önceki değil şimdiki olmalı.
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

  /// İncelemeye göre aşamayı seçer. Kullanıcı zaten doğrulanmışsa inceleme
  /// ne derse desin onay görünümü: bayrak son söz.
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

  /// Kaynağı sorup kareyi alır, sınırlardan geçirir, yerine koyar.
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
          setState(() => progress = total > 0 ? sent / total : null);
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

  /// Sunucunun reddini ekranın yapacağı şeye çevirir.
  ///
  /// Tanınan kodlarda bizim metnimiz ve [IdentityDocumentAction]; tanınmayan
  /// kodda sunucunun kendi metni ve form olduğu gibi kalıyor.
  Future<void> _handleSubmitFailure(ApiException error) async {
    final known = IdentityDocumentError.of(error);

    switch (known?.action) {
      case IdentityDocumentAction.showStatus:
        // Sunucu bizim bildiğimizden başka bir durumda: yeniden okuyup ona
        // göre çiz. Okuma da başarısız olursa form ve mesaj kalıyor.
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

  /// Bekleme görünümünden durumu yeniden okur.
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

  /// Bekleme görünümünden çıkış: doğrulama tamamlanmadı, `false`.
  void leave() => context.pop(false);

  /// Onay görünümünden çıkış: `/users/me` tazelenip `true` ile kapanıyor,
  /// çağıran kapı taze bayrağa bakıyor.
  Future<void> leaveVerified() async {
    await context.read<UserProvider>().load(silent: true);
    if (!mounted) return;
    context.pop(true);
  }
}
