part of 'account_info_page.dart';

/// Hesap bilgileri ekranının durumu ve iş mantığı.
///
/// Sayfa on kontrolcü, `initState`/`dispose` ve `build` dışında beş iş
/// mantığı metodu taşıyor; CONTRIBUTING'in "Page & PageModel Ayrımı"
/// ölçütlerinin üçü de karşılandığı için UI tarafı `account_info_page.dart`
/// içinde yalnız bırakıldı.
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
    // IBAN sunucudan maskeli geliyor; alan boş açılıyor ve maske ipucu
    // olarak gösteriliyor. Maskeyi alana yazsaydık kullanıcı kaydettiğinde
    // maskenin kendisi IBAN diye gönderilirdi.
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

  /// Kimliği doğrulanmış kullanıcı ad ve soyadını değiştiremiyor; backend
  /// isteği reddettiği için alanlar en baştan kapalı açılıyor.
  bool get canEditName => !widget.user.identityVerified;

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
      AppToast.success(context, 'Profil fotoğrafın güncellendi.');
    } else {
      AppToast.error(
        context,
        provider.errorMessage ?? 'Profil fotoğrafı yüklenemedi.',
      );
    }
  }

  Future<void> save() async {
    final provider = context.read<UserProvider>();
    // Karşılaştırma tabanı sağlayıcıdaki güncel kullanıcı: doğrulama
    // tamamlandıktan sonra alanlar tazeleniyor ve `widget.user` (ekrana
    // girilirken alınan görüntü) bayatlıyor. Bayat tabanla ikinci kaydetme,
    // hiçbir şey değişmemişken e-postayı yeniden gönderir ve gereksiz bir
    // doğrulama daha başlatırdı.
    final user = provider.user ?? widget.user;

    // PATCH kısmi: değişmeyen alan gövdeye hiç konmuyor. Aksi hâlde kimliği
    // doğrulanmış kullanıcı hiçbir şeyi değiştirmese bile ad alanını
    // gönderdiği için hata alırdı.
    final firstName = _changed(firstNameController.text, user.firstName);
    final lastName = _changed(lastNameController.text, user.lastName);
    final about = _changed(aboutController.text, user.about);
    final phoneNumber = _changed(phoneController.text, user.phoneNumber);
    final jobTitle = _changed(occupationController.text, user.jobTitle);
    final qualifications = _changed(
      qualificationsController.text,
      user.qualifications,
    );
    final interests = _changed(interestsController.text, user.interests);
    // E-posta ve telefon değişikliği hemen yazılmıyor: sunucu yeni değere kod
    // gönderip bekleyen doğrulamayı döndürüyor.
    final email = _changed(emailController.text, user.email);

    // IBAN alanı boş bırakıldıysa hiç gönderilmiyor: kayıtlı IBAN
    // maskelendiği için "değişti mi" karşılaştırması yapılamıyor, boş metin
    // göndermek de kayıtlıyı bozardı.
    final iban = ibanController.text.trim();

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
      // Backend başka hesapta kayıtlı e-postayı reddediyor. Durum koduna
      // bakılmıyor, bakılmamalı da: `UsersController`'ın `@ApiResponse`'u bu
      // durum için `409` belgeliyor ama `UserManager` `ValidationException`
      // fırlattığı için gerçekte `400` dönüyor. Mesaj sunucudan Türkçe
      // geldiği için olduğu gibi gösteriliyor.
      AppToast.error(
        context,
        provider.errorMessage ?? "Profil güncellenemedi.",
      );
      return;
    }

    if (pending.isEmpty) {
      AppToast.success(context, "Profilin güncellendi.");
      context.pop();
      return;
    }

    await _collectVerifications(pending);
  }

  /// Bekleyen doğrulamaları sırayla kod ekranına götürür.
  ///
  /// Tek bir `PATCH` hem telefonu hem e-postayı değiştirebiliyor, o yüzden
  /// liste birden fazla olabilir. Biri onaylanınca sıradaki açılıyor;
  /// kullanıcı vazgeçerse ya da kayıt geçersizse sıra orada kesiliyor —
  /// kalanları zorlamak, kullanıcının bıraktığı ekranı geri açmak olurdu.
  ///
  /// Hepsi bitince hesap ekranında kalınıyor ve alanlar tazelenen kullanıcıyla
  /// güncelleniyor; yeni değerin yazıldığı böylece görülebiliyor.
  Future<void> _collectVerifications(List<PendingVerification> pending) async {
    for (final verification in pending) {
      final verified = await context.push<bool>(
        '/verification',
        extra: verification,
      );
      if (!mounted) return;
      if (verified != true) break;
    }

    if (!mounted) return;
    _syncVerifiedFields();
  }

  /// Doğrulama sonrası sunucudaki güncel değerleri alanlara yazar.
  ///
  /// Kontrolcüler `initState`'te bir kez dolduruluyor; tazelenen kullanıcıyı
  /// buraya yansıtmazsak ekran hâlâ eski e-postayı gösterirdi.
  void _syncVerifiedFields() {
    final refreshed = context.read<UserProvider>().user;
    if (refreshed == null) return;

    setState(() {
      emailController.text = refreshed.email;
      phoneController.text = refreshed.phoneNumber ?? '';
    });
  }

  /// Yeni değer eskisinden farklıysa onu, aynıysa `null` döner.
  static String? _changed(String value, String? current) {
    final trimmed = value.trim();
    return trimmed == (current ?? '') ? null : trimmed;
  }
}
