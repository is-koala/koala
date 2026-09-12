part of 'identity_verification_page.dart';

abstract class IdentityVerificationPagemodel
    extends State<IdentityVerificationPage> {
  late final UserService _userService;

  /// Elle beyanın taslağı. Çip okunduğunda **dokunulmuyor**: kilitli ekran
  /// bu denetleyicileri hiç okumuyor, okuma kaldırıldığında da taslak
  /// olduğu gibi geri geliyor.
  late final TextEditingController firstName;
  late final TextEditingController lastName;
  late final TextEditingController tcIdentity;
  late final TextEditingController tcDocument;

  DateTime? birthDate;
  bool isSubmitting = false;

  /// Çipten okunan kanıt ve ondan türeyen kart sahibi. `null` ise akış
  /// **eskisi gibi** çalışıyor: beyan formu doldurulup gönderiliyor ve
  /// sunucu bayrağı kapalı olduğu için istek aynen kabul ediliyor.
  ///
  /// Çipten türeyen beş alan **ayrıca saklanmıyor**; hepsi bu nesnenin
  /// görünümü. Bu yüzden "kanıt gitti ama kilitli değerler kaldı" ya da
  /// tersi bir durum yazılamıyor: `chip = null` ikisini birden bırakıyor.
  IdentityChipResult? chip;

  /// Doğum tarihi seçicinin gidebileceği en eski yıl.
  static const int earliestYear = 1920;

  /// Çalışma yaşı alt sınırı; seçici bundan yenisini göstermiyor.
  static const int minimumAge = 15;

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService();
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

  /// Ekranın gösterdiği ve göndereceği beyan — **tek kaynak**.
  ///
  /// Çip varsa [ChipDeclaration]: beş alan kanıttan türüyor ve
  /// denetleyicilerdeki taslak hiç okunmuyor. Yoksa [ManualDeclaration]:
  /// denetleyicilerin o anki metni. Hangi hâlde olunduğu ayrı bir bayrakla
  /// değil beyanın tipiyle belli; `build` ve [submit] aynı nesneye bakıyor.
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

  /// Çip okuma ekranını açar ve dönen sonucu forma işler.
  ///
  /// Ekran `null` ile kapanırsa hiçbir şey değişmiyor: kullanıcı vazgeçmiş
  /// ya da NFC yokmuş demektir ve eldeki durum — beyan formu ya da önceki
  /// okuma — olduğu gibi duruyor. Geçerli bir okumayı, ikinci denemeden
  /// vazgeçildi diye atmak kartı boşuna yeniden okutmak olurdu.
  Future<void> readChip() async {
    final result = await context.push<IdentityChipResult>('/identity-chip');
    if (!mounted || result == null) return;

    setState(() => chip = result);
  }

  /// Okumayı bırakır: kanıt ve ondan türeyen beş alan **tek geçişte**
  /// gidiyor, form elle düzenlemeye dönüyor. Elle düzenlemeye dönüşün
  /// başka yolu yok.
  void removeChip() => setState(() => chip = null);

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
    // Gövde ekrandaki beyandan kuruluyor, denetleyicilerden değil: çip
    // varken denetleyicilerde ne yazdığının bir önemi yok.
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
        // Kanıt varsa aynı istekte gidiyor; yoksa gövde eskisiyle birebir
        // aynı kalıyor.
        evidence: declaration.evidence,
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
    // verir; elde tutulan kanıt artık geçersiz, baştan okunmalı. Kanıtla
    // birlikte ondan türeyen alanlar da gidiyor — kanıtsız kalan değerleri
    // beyan diye göstermek, kilidin kapattığı açığı geri açmak olurdu.
    if (known.needsFreshChallenge) removeChip();
  }
}
