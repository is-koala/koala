part of 'account_info_page.dart';

abstract class AccountInfoPagemodel extends State<AccountInfoPage> {
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController occupationController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  late TextEditingController locationController;
  late TextEditingController ibanController;
  late TextEditingController aboutController;
  late TextEditingController qualificationsController;
  late TextEditingController interestsController;

  @override
  void initState() {
    super.initState();
    final user = widget.user;

    firstNameController = TextEditingController(text: user.firstName);
    lastNameController = TextEditingController(text: user.lastName);
    occupationController = TextEditingController(text: user.jobTitle ?? '');
    phoneController = TextEditingController(text: user.phoneNumber ?? '');
    emailController = TextEditingController(text: user.email);
    locationController = TextEditingController(
      text: user.address?.shortLabel ?? '',
    );
    // IBAN maskeli geliyor; maske alana yazılsa kaydedince IBAN diye
    // gönderilirdi. Alan boş açılır, maske ipucu olur.
    ibanController = TextEditingController();
    aboutController = TextEditingController(text: user.about ?? '');
    qualificationsController = TextEditingController(
      text: user.qualifications ?? '',
    );
    interestsController = TextEditingController(text: user.interests ?? '');
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    occupationController.dispose();
    phoneController.dispose();
    emailController.dispose();
    locationController.dispose();
    ibanController.dispose();
    aboutController.dispose();
    qualificationsController.dispose();
    interestsController.dispose();
    super.dispose();
  }

  bool get canEditName => !widget.user.identityVerified;

  bool get showsWorkerFields => !widget.user.isEmployer;

  Future<void> pickProfilePicture() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;

    final provider = context.read<UserProvider>();
    final uploaded = await provider.uploadProfilePicture(image.path);
    if (!mounted) return;
    if (uploaded) {
      AppToast.success(context, 'Profil fotoğrafınız güncellendi.');
    } else {
      AppToast.error(
        context,
        provider.errorMessage ?? 'Profil fotoğrafı yüklenemedi.',
      );
    }
  }

  Future<void> save() async {
    final provider = context.read<UserProvider>();
    // Taban sağlayıcıdaki güncel kullanıcı: doğrulamadan sonra `widget.user`
    // bayatlıyor ve ikinci kaydetme e-postayı boşuna yeniden gönderirdi.
    final user = provider.user ?? widget.user;

    // `PATCH` kısmi: değişmeyen alan gönderilmez, yoksa kimliği doğrulanmış
    // kullanıcı ad alanı yüzünden hata alırdı.
    final firstName = _changed(firstNameController.text, user.firstName);
    final lastName = _changed(lastNameController.text, user.lastName);
    final phoneNumber = _changed(phoneController.text, user.phoneNumber);
    // Gövdeye girip girmemeleri kontrolcüye değil role bağlı.
    final about = showsWorkerFields
        ? _changed(aboutController.text, user.about)
        : null;
    final jobTitle = showsWorkerFields
        ? _changed(occupationController.text, user.jobTitle)
        : null;
    final qualifications = showsWorkerFields
        ? _changed(qualificationsController.text, user.qualifications)
        : null;
    final interests = showsWorkerFields
        ? _changed(interestsController.text, user.interests)
        : null;
    // E-posta ve telefon hemen yazılmıyor; sunucu kod gönderip bekliyor.
    final email = _changed(emailController.text, user.email);

    // Boş IBAN gönderilmez: kayıtlı IBAN maskeli olduğu için karşılaştırma
    // yapılamıyor, boş metin kayıtlıyı bozardı.
    final iban = showsWorkerFields ? ibanController.text.trim() : '';

    final pending = await provider.updateProfile(
      firstName: canEditName ? firstName : null,
      lastName: canEditName ? lastName : null,
      about: about,
      jobTitle: jobTitle,
      qualifications: qualifications,
      interests: interests,
      phoneNumber: phoneNumber,
      email: email,
      iban: iban.isEmpty ? null : iban,
    );

    if (!mounted) return;

    if (pending == null) {
      // Başka hesaptaki e-posta reddediliyor; belge `409` dese de gerçekte
      // `400` döndüğü için koda bakılmıyor, Türkçe mesaj gösteriliyor.
      AppToast.error(
        context,
        provider.errorMessage ?? "Profil güncellenemedi.",
      );
      return;
    }

    if (pending.isEmpty) {
      AppToast.success(context, "Profiliniz güncellendi.");
      context.pop();
      return;
    }

    await _collectVerifications(pending);
  }

  /// Bekleyen doğrulamaları sırayla kod ekranına götürür (tek `PATCH` hem
  /// telefonu hem e-postayı değiştirebilir). Kullanıcı vazgeçerse sıra kesilir.
  Future<void> _collectVerifications(List<PendingVerification> pending) async {
    for (final verification in pending) {
      final verified = await context.push<bool>(
        AccountRoutes.verification,
        extra: verification,
      );
      if (!mounted) return;
      if (verified != true) break;
    }

    if (!mounted) return;
    _syncVerifiedFields();
  }

  /// Kontrolcüler bir kez dolduruluyor; doğrulamadan sonra güncel değerler
  /// buradan yansır.
  void _syncVerifiedFields() {
    final refreshed = context.read<UserProvider>().user;
    if (refreshed == null) return;

    setState(() {
      emailController.text = refreshed.email;
      phoneController.text = refreshed.phoneNumber ?? '';
    });
  }

  Future<void> openAddress() => _editOnOwnPage(AccountRoutes.address);

  Future<void> openIdentityVerification() =>
      _editOnOwnPage('/identity-verification');

  /// Kendi ekranında düzenlenen alana gider ve dönüşte bu ekranı kapatır:
  /// `widget.user` o arada bayatlıyor.
  Future<void> _editOnOwnPage(String route) async {
    await context.push(route, extra: widget.user);
    if (mounted) context.pop();
  }

  static String? _changed(String value, String? current) {
    final trimmed = value.trim();
    return trimmed == (current ?? '') ? null : trimmed;
  }
}
