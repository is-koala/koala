part of 'b_company_gallery_page.dart';

abstract class BCompanyGalleryPagemodel extends State<BCompanyGalleryPage> {
  static const String _adminRole = 'ADMIN';

  /// Sunucu yanıtına kadar gösterilen sıra; yoksa liste eski sıraya dönüp sonra
  /// yerine oturur.
  List<GalleryImage>? _pendingOrder;

  List<GalleryImage> get images =>
      _pendingOrder ?? context.read<BCompanyProvider>().galleryImages;

  /// Rol `/users/me`'deki üyelikte. Yetkisiz `404` aldığı için denetimler
  /// çizilmiyor.
  bool get canManage =>
      context.watch<UserProvider>().user?.primaryCompany?.role == _adminRole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  void reload({bool force = false}) {
    if (!mounted) return;

    final user = context.read<UserProvider>().user;
    if (user != null) {
      context.read<BCompanyProvider>().loadFor(user, force: force);
    }
  }

  // ---------------------------------------------------------------- Ekleme

  /// Uzantı ve boyut istemcide de kontrol ediliyor; dosya ham gönderiliyor.
  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final error = await BGalleryUploadValidator.errorFor(picked.path);
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

  /// İstek yalnız sürükleme bitince atılıyor. `onReorderItem` hedefi zaten
  /// düzeltilmiş veriyor.
  Future<void> onReorder(int oldIndex, int newIndex) async {
    final reordered = [...images];
    reordered.insert(newIndex, reordered.removeAt(oldIndex));

    setState(() => _pendingOrder = reordered);

    await _run(
      () => context.read<BCompanyProvider>().replaceGallery(reordered),
      successMessage: 'Sıralama kaydedildi',
    );
  }

  /// Eski kapağın bayrağı da düşer: birden çok kapak `400`.
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

  Future<void> _run(
    Future<bool> Function() action, {
    required String successMessage,
  }) async {
    final provider = context.read<BCompanyProvider>();
    final succeeded = await action();

    if (!mounted) return;
    // Sunucunun listesi tek kaynak.
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
