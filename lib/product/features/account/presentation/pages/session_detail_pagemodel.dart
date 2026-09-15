part of 'session_detail_page.dart';

abstract class SessionDetailPagemodel extends State<SessionDetailPage> {
  late final SessionService _service = widget.service ?? SessionService();

  late SessionDetail detail = widget.initial;

  /// Adlandırma ya da kapatma havada mı. İkisi aynı anda koşmuyor.
  bool isWorking = false;

  /// Cihaz adının üst sınırı; sunucu `@Size(max = 60)` ile aynı sayıyı
  /// tutuyor, kutu daha uzununu yazdırmıyor.
  static const int nameMaxLength = 60;

  /// Ayrıntıyı sunucudan yeniden çeker.
  ///
  /// Hata sessiz geçiyor: elde zaten gösterilecek bir ayrıntı var, eskisi
  /// kalıyor. Oturum bu arada kapandıysa (`404`) sayfa kapanıyor ve liste
  /// kendini tazeliyor.
  Future<void> reload() async {
    try {
      final fresh = await _service.fetchDetail(detail.id);
      if (!mounted) return;
      setState(() => detail = fresh);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.type == ApiErrorType.notFound) {
        context.pop(true);
        return;
      }
      AppToast.error(context, error.message);
    }
  }

  /// "Cihazı adlandır": adı sorar, sunucuya yazar, ayrıntıyı tazeler.
  ///
  /// Kutu kullanıcının **kendi** verdiği adla açılıyor
  /// ([SessionDetail.deviceCustomName]); sunucunun türettiği ad kutuya
  /// konsaydı kullanıcı onu kendi yazmış sanırdı. Boş ad `400` — kutu boşken
  /// onayı kapalı tutuyor, sunucuya gitmeden.
  Future<void> rename() async {
    final deviceId = detail.deviceId;
    if (isWorking || deviceId == null) return;

    final name = await ReasonDialog.show(
      context,
      title: 'Cihazı adlandır',
      description:
          'Ad yalnızca sizin oturum listenizde görünür; bu cihazın '
          'sonraki oturumları da bu adla listelenir.',
      fieldLabel: 'Cihaz adı',
      confirmLabel: 'Kaydet',
      isDestructive: false,
      initialText: detail.deviceCustomName,
      maxLength: nameMaxLength,
    );

    if (name == null || !mounted) return;
    setState(() => isWorking = true);

    try {
      await _service.renameDevice(deviceId, name);
      await reload();
      if (mounted) AppToast.success(context, 'Cihaz adı kaydedildi');
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => isWorking = false);
    }
  }

  /// "Oturumu kapat": onay ister, kapatır ve `true` ile sayfayı kapatır;
  /// liste bu değeri görünce kendini yeniden çekiyor.
  Future<void> revoke() async {
    if (isWorking) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Oturumu kapat',
      message:
          '"${detail.displayName}" cihazındaki oturum kapatılacak. '
          'O cihaz yeniden giriş yapmak zorunda kalacak.',
      actionLabel: 'Kapat',
    );

    if (confirmed != true || !mounted) return;
    setState(() => isWorking = true);

    try {
      await _service.revoke(detail.id);
      if (!mounted) return;
      AppToast.success(context, 'Oturum kapatıldı');
      context.pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.message);
      setState(() => isWorking = false);
    }
  }
}
