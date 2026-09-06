part of 'identity_verification_page.dart';

abstract class IdentityVerificationPagemodel
    extends State<IdentityVerificationPage> {
  final UserService _userService = UserService();

  late final TextEditingController firstName;
  late final TextEditingController lastName;
  late final TextEditingController tcIdentity;
  late final TextEditingController tcDocument;

  DateTime? birthDate;
  bool isSubmitting = false;

  /// Çipten okunan kanıt. `null` ise akış **eskisi gibi** çalışıyor: beyan
  /// formu doldurulup gönderiliyor ve sunucu bayrağı kapalı olduğu için
  /// istek aynen kabul ediliyor.
  IdentityChipResult? chip;

  /// TC kimlik numarası tam 11 hane.
  static const int tcIdentityLength = 11;

  /// Doğum tarihi seçicinin gidebileceği en eski yıl.
  static const int earliestYear = 1920;

  /// Çalışma yaşı alt sınırı; seçici bundan yenisini göstermiyor.
  static const int minimumAge = 15;

  @override
  void initState() {
    super.initState();
    // Kayıtta girilen ad ve soyad çoğu kullanıcıda kimliktekiyle aynı;
    // form boş açılırsa gereksiz yere yeniden yazdırmış oluruz.
    firstName = TextEditingController(text: widget.user.firstName);
    lastName = TextEditingController(text: widget.user.lastName);
    tcIdentity = TextEditingController();
    tcDocument = TextEditingController();
    birthDate = widget.user.birthDate;
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    tcIdentity.dispose();
    tcDocument.dispose();
    super.dispose();
  }

  /// Çip oturumu açıldıysa belge numarası ve doğum tarihi **kanıtlanmış**
  /// demektir: BAC/PACE anahtarı bu ikisinden (ve son geçerlilik
  /// tarihinden) türüyor ve yanlışlarsa oturum hiç açılmıyor. Kullanıcıya
  /// yeniden yazdırmak, yalnızca yanlış yazma fırsatı vermek olurdu.
  bool get isLockedByChip => chip != null;

  /// Gönderilebilir mi. Sunucunun deseni ayrıca doğruluyor; buradaki kontrol
  /// kullanıcıyı boşuna bir gidiş dönüşten kurtarıyor.
  bool get canSubmit =>
      firstName.text.trim().isNotEmpty &&
      lastName.text.trim().isNotEmpty &&
      tcIdentity.text.trim().length == tcIdentityLength &&
      tcDocument.text.trim().isNotEmpty &&
      birthDate != null;

  /// Çip okuma ekranını açar ve dönen kanıtı forma işler.
  ///
  /// Ekran `null` ile kapanırsa hiçbir şey değişmiyor: kullanıcı vazgeçmiş
  /// ya da NFC yokmuş demektir ve beyan formu olduğu gibi duruyor.
  Future<void> readChip() async {
    final result = await context.push<IdentityChipResult>('/identity-chip');
    if (!mounted || result == null) return;

    setState(() {
      chip = result;
      tcDocument.text = result.key.documentNumber;
      birthDate = result.key.birthDate;

      // TCKN MRZ'nin isteğe bağlı veri alanından geliyor ve BAC anahtarının
      // parçası **değil** — yani oturumun açılması onu kanıtlamıyor. Bu
      // yüzden yalnızca ön dolduruluyor, kilitlenmiyor.
      final identityNumber = result.key.nationalIdentityNumber;
      if (identityNumber != null) tcIdentity.text = identityNumber;
    });
  }

  Future<void> pickBirthDate() async {
    final now = DateTime.now();
    final latest = DateTime(now.year - minimumAge, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate ?? latest,
      firstDate: DateTime(earliestYear),
      lastDate: latest,
    );
    if (picked == null) return;

    setState(() => birthDate = picked);
  }

  Future<void> submit() async {
    setState(() => isSubmitting = true);

    try {
      await _userService.verifyIdentity(
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        birthDate: birthDate!,
        tcIdentityNumber: tcIdentity.text.trim(),
        tcDocumentNumber: tcDocument.text.trim(),
        // Kanıt varsa aynı istekte gidiyor; yoksa gövde eskisiyle birebir
        // aynı kalıyor.
        evidence: chip?.evidence,
      );

      if (!mounted) return;
      // `identityVerified` bayrağı `/users/me`'den okunuyor; başvuru kapısı
      // da oraya bakıyor, o yüzden kullanıcı tazelenmeden dönülmemeli.
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

  /// Sunucunun hatasını kullanıcıya ne yapacağını söyleyen bir mesaja
  /// çevirir.
  ///
  /// Sunucunun kendi metni **ne olduğunu** anlatıyor, **ne yapılacağını**
  /// değil; tanınan `IDENTITY_*` kodlarında bizim karşılığımız gösteriliyor.
  /// Tanınmayan kodda sunucunun mesajı olduğu gibi kalıyor — uydurulmuş bir
  /// yönlendirme, hiç yönlendirmemekten kötü.
  void _showFailure(ApiException error) {
    final known = IdentityError.fromErrorCode(error.errorCode);
    AppToast.error(context, known?.message ?? error.message);

    if (known == null) return;

    // Süresi dolmuş tek kullanımlık sayıyla ikinci kez denemek aynı hatayı
    // verir; elde tutulan kanıt artık geçersiz, baştan okunmalı.
    if (known.needsFreshChallenge) {
      setState(() => chip = null);
    }
  }
}
