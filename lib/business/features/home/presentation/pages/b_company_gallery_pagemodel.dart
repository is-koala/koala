part of 'b_company_gallery_page.dart';

abstract class BCompanyGalleryPagemodel extends State<BCompanyGalleryPage> {
  /// Şirketteki `ADMIN` rolünün sunucudaki adı (`CompanyContactRole`).
  /// Diğer değer `STAFF` ve o galeriyi yalnız görüyor.
  static const String _adminRole = 'ADMIN';

  /// Sürükleme sonrası sunucudan yanıt gelene kadar gösterilen sıra.
  ///
  /// Olmasaydı liste bırakıldığı anda eski sırasına dönüp istek bitince
  /// yeniden yerine oturur, sürükleme geri alınmış gibi görünürdü.
  List<GalleryImage>? _pendingOrder;

  /// Ekranda çizilecek galeri.
  List<GalleryImage> get images =>
      _pendingOrder ?? context.read<BCompanyProvider>().galleryImages;

  /// Kullanıcı bu şirketin yöneticisi mi.
  ///
  /// Rol `/users/me` yanıtındaki üyelik kaydında duruyor. Yetkisiz kullanıcı
  /// sunucudan `403` değil `404` alıyor, o yüzden denetimler hiç çizilmiyor.
  bool get canManage =>
      context.watch<UserProvider>().user?.primaryCompany?.role == _adminRole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  /// Şirketi (ve gövdesindeki galeriyi) çeker.
  void reload({bool force = false}) {
    if (!mounted) return;

    final user = context.read<UserProvider>().user;
    if (user != null) {
      context.read<BCompanyProvider>().loadFor(user, force: force);
    }
  }

  // ---------------------------------------------------------------- Ekleme

  /// Galeriden bir görsel seçip yükler.
  ///
  /// Uzantı ve boyut istemcide de kontrol ediliyor: sunucu aynı kuralları
  /// uyguluyor ama kullanıcıyı yüklemeyi bekleyip hata almaya bırakmanın
  /// anlamı yok. Dosya ham gönderiliyor, logo akışındaki gibi.
  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final error = await GalleryUploadValidator.errorFor(picked.path);
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
      return;
    }

    await _run(
      () => context.read<BCompanyProvider>().addGalleryImage(picked.path),
      successMessage: 'Görsel eklendi',
    );
  }

  // -------------------------------------------------------- Sıra ve kapak

  /// Sürükleme bittiğinde çalışır; istek yalnızca burada atılıyor.
  ///
  /// `onReorderItem` hedefi kaldırılmış öğeye göre düzelterek veriyor, o
  /// yüzden eski `onReorder`'ın `newIndex - 1` düzeltmesi burada yok.
  Future<void> onReorder(int oldIndex, int newIndex) async {
    final reordered = [...images];
    reordered.insert(newIndex, reordered.removeAt(oldIndex));

    setState(() => _pendingOrder = reordered);

    // Galerinin tamamı gidiyor: listede olmayan görsel sunucuda siliniyor.
    await _run(
      () => context.read<BCompanyProvider>().replaceGallery(reordered),
      successMessage: 'Sıralama kaydedildi',
    );
  }

  /// Seçilen görseli kapak yapar.
  ///
  /// Eski kapağın bayrağı da düşürülüyor: sunucu birden fazla kapak taşıyan
  /// gövdeyi `400` ile geri çeviriyor.
  Future<void> setCover(GalleryImage image) async {
    final updated = [
      for (final current in images) current.copyWith(isCover: current == image),
    ];

    await _run(
      () => context.read<BCompanyProvider>().replaceGallery(updated),
      successMessage: 'Kapak güncellendi',
    );
  }

  // --------------------------------------------------------------- Kaldırma

  Future<void> remove(GalleryImage image) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Görseli kaldır',
      message: image.isCover
          ? 'Bu görsel kapak. Kaldırılırsa sıradaki görsel kapak olur.'
          : 'Görsel galeriden kaldırılacak.',
      actionLabel: 'Kaldır',
    );

    if (confirmed != true || !mounted) return;

    await _run(
      () => context.read<BCompanyProvider>().removeGalleryImage(image.id),
      successMessage: 'Görsel kaldırıldı',
    );
  }

  /// Üç galeri eyleminin ortak sonu: bekleyen sırayı düşürür ve sonucu yazar.
  Future<void> _run(
    Future<bool> Function() action, {
    required String successMessage,
  }) async {
    final provider = context.read<BCompanyProvider>();
    final succeeded = await action();

    if (!mounted) return;
    // Sunucudan dönen liste tek doğru kaynak; yerel sıra artık gereksiz.
    setState(() => _pendingOrder = null);

    if (succeeded) {
      AppToast.success(context, successMessage);
    } else {
      AppToast.error(
        context,
        provider.galleryErrorMessage ?? 'İşlem tamamlanamadı',
      );
    }
  }
}
