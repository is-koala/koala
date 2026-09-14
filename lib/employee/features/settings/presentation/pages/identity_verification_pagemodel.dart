part of 'identity_verification_page.dart';

abstract class IdentityVerificationPagemodel
    extends State<IdentityVerificationPage> {
  late final UserService _userService;
  late final ChipReader _chipReader;

  /// Elle beyanın taslağı. Çip okunduğunda **dokunulmuyor**: kilitli ekran
  /// bu denetleyicileri hiç okumuyor, okuma kaldırıldığında da taslak
  /// olduğu gibi geri geliyor.
  late final TextEditingController firstName;
  late final TextEditingController lastName;
  late final TextEditingController tcIdentity;
  late final TextEditingController tcDocument;

  DateTime? birthDate;
  bool isSubmitting = false;

  /// Giriş kararı verildi ve bu ekran çizilecek. `false` iken ya karar
  /// bekleniyor ya da fotoğraf akışı üstte açık ve bu ekran onun sonucuyla
  /// kapanacak.
  bool isReady = false;

  /// Çip yolu az önce başarısız oldu — cihazda okunamadı ya da sunucu
  /// kanıtı reddetti. Fotoğraf kartı uyarı olarak çiziliyor.
  bool chipFailed = false;

  /// Çipten okunan kanıt ve ondan türeyen kart sahibi. `null` ise akış
  /// **eskisi gibi** çalışıyor: beyan formu doldurulup gönderiliyor ve
  /// sunucu bayrağı kapalı olduğu için istek aynen kabul ediliyor.
  ///
  /// Çipten türeyen beş alan **ayrıca saklanmıyor**; hepsi bu nesnenin
  /// görünümü. Bu yüzden "kanıt gitti ama kilitli değerler kaldı" ya da
  /// tersi bir durum yazılamıyor: `chip = null` ikisini birden bırakıyor.
  IdentityChipResult? chip;

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService();
    _chipReader = widget.chipReader ?? ChipReader();
    // Kayıtta girilen ad ve soyad çoğu kullanıcıda kimliktekiyle aynı;
    // form boş açılırsa gereksiz yere yeniden yazdırmış oluruz.
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

  // ------------------------------------------------------------------ Giriş

  /// Hangi yolun açılacağına karar verir.
  ///
  /// Fotoğraf akışına **doğrudan** gidilen üç hâl var: zaten bir inceleme
  /// kaydı var (bekliyor, reddedildi ya da onaylandı — üçünün de ekranı
  /// orada), telefon iOS (çip okuma bu sürümde açık değil) ya da NFC
  /// donanımı yok. Bu hâllerde bu ekranın gösterecek bir şeyi yok:
  /// fotoğraf akışı kapanınca aynı sonuçla kapanıyor ki çağıran kapı tek
  /// bir `push` sonucu görsün.
  ///
  /// İnceleme durumu okunamazsa "yok" sayılıyor: ağ hatası yüzünden
  /// kullanıcıyı çip formundan mahrum etmek yerine form açılıyor, fotoğraf
  /// yolu zaten tepede.
  Future<void> enter() async {
    final provider = context.read<IdentityReviewProvider?>();
    if (provider != null) await provider.load(silent: true);
    if (!mounted) return;

    final hasReview = provider?.review != null;
    final chipPossible = await _chipPossible();
    if (!mounted) return;

    if (hasReview || widget.user.identityVerified || !chipPossible) {
      final result = await context.push<bool>(
        '/identity-documents',
        extra: widget.user,
      );
      if (mounted) context.pop(result ?? false);
      return;
    }

    setState(() => isReady = true);
  }

  /// Çip yolu bu cihazda denenebilir mi.
  ///
  /// iOS'ta hayır: kart okuma Apple'ın NFC yetkisini istiyor ve bu sürüm
  /// onu taşımıyor. Android'de NFC donanımı yoksa hayır; **kapalıysa** evet,
  /// kullanıcı ayarlardan açabiliyor ve çip ekranı bunu söylüyor.
  Future<bool> _chipPossible() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) return false;
    final availability = await _chipReader.availability();
    return availability != NfcAvailability.unsupported;
  }

  /// Fotoğraf akışını açar.
  ///
  /// Dönüşte bir inceleme kaydı oluşmuşsa (kullanıcı gönderdi) ya da akış
  /// `true` ile kapandıysa bu ekranın yapacağı bir şey kalmadı, o da
  /// kapanıyor. Kullanıcı hiçbir şey yapmadan geri döndüyse çip formu
  /// olduğu yerde duruyor.
  Future<void> openPhotos() async {
    final provider = context.read<IdentityReviewProvider?>();
    final result = await context.push<bool>(
      '/identity-documents',
      extra: widget.user,
    );
    if (!mounted) return;

    if (result == true || provider?.review != null) {
      context.pop(result ?? false);
    }
  }

  // ------------------------------------------------------------------- Çip

  /// Çip okuma ekranını açar ve dönen sonucu forma işler.
  ///
  /// Üç sonuç var: okunan kanıt forma yazılıyor; `IdentityChipHandoff.photos`
  /// kullanıcının hata ekranından "Fotoğrafla Devam Et" dediği anlamına
  /// geliyor ve fotoğraf akışı açılıyor; `null` ise hiçbir şey değişmiyor
  /// — kullanıcı vazgeçmiş ya da NFC yokmuş demektir ve eldeki durum
  /// olduğu gibi duruyor. Geçerli bir okumayı, ikinci denemeden vazgeçildi
  /// diye atmak kartı boşuna yeniden okutmak olurdu.
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

  /// Okumayı bırakır: kanıt ve ondan türeyen beş alan **tek geçişte**
  /// gidiyor, form elle düzenlemeye dönüyor.
  ///
  /// Elle düzenlemeye dönüşün tek geçişi bu ve iki yerden tetikleniyor:
  /// kullanıcının karttaki "Okumayı Kaldır"ı ve sunucunun eldeki kanıtı
  /// artık kabul etmeyeceğini söylediği `IDENTITY_CHALLENGE_INVALID` yanıtı
  /// ([_showFailure]). İkincisi de aynı yoldan geçiyor, çünkü geçersiz
  /// kanıtın türevlerini kilitli beyan diye göstermek, kanıtla beyanın
  /// ayrışmasına izin vermek olurdu.
  void removeChip() => setState(() => chip = null);

  // --------------------------------------------------------------- Gönderim

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
  /// çevirir ve fotoğraf yolunu öne çıkarır.
  ///
  /// Sunucunun kendi metni **ne olduğunu** anlatıyor, **ne yapılacağını**
  /// değil; tanınan `IDENTITY_*` kodlarında bizim karşılığımız gösteriliyor.
  /// Tanınmayan kodda sunucunun mesajı olduğu gibi kalıyor — uydurulmuş bir
  /// yönlendirme, hiç yönlendirmemekten kötü. Kod ne olursa olsun çip yolu
  /// bu sefer yürümedi; fotoğraf kartı uyarı olarak çiziliyor ki kullanıcı
  /// aynı okumayı döngüye girmeden bırakabilsin.
  void _showFailure(ApiException error) {
    final known = IdentityError.fromErrorCode(error.errorCode);
    AppToast.error(context, known?.message ?? error.message);
    setState(() => chipFailed = true);

    if (known == null) return;

    // Süresi dolmuş tek kullanımlık sayıyla ikinci kez denemek aynı hatayı
    // verir: `challenge` ve imzası kanıtın parçası, kanıt bir bütün olarak
    // geçersiz ve baştan okunmalı. Bu, elle düzenlemeye dönüşün kullanıcı
    // eylemi olmayan tek yolu ve bilerek [removeChip] ile aynı geçiş —
    // sunucunun az önce reddettiği kanıtı "doğrulandı" diye ekranda tutmak,
    // kilidin kapattığı açığı (kanıtla ayrışan beyan) geri açmak olurdu.
    // Yalnız bu kodda: imza ya da makam hatası kanıtı geçersiz kılmıyor,
    // kullanıcı toast'taki yönlendirmeyle yeniden okutur ya da desteğe yazar.
    if (known.needsFreshChallenge) removeChip();
  }
}
