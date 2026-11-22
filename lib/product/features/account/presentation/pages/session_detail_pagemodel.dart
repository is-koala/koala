part of 'session_detail_page.dart';

abstract class SessionDetailPagemodel extends State<SessionDetailPage> {
  late final SessionService _service = widget.service ?? SessionService();

  late SessionDetail detail = widget.initial;

  bool isWorking = false;

  /// Sunucunun `@Size(max = 60)` sınırı.
  static const int nameMaxLength = 60;

  /// Ayrıntıyı yeniden çeker. Hata sessiz, eldeki kalır; oturum kapandıysa
  /// (`404`) sayfa kapanır.
  Future<void> reload() async {
    try {
      final fresh = await _service.fetchDetail(detail.session.id);
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

  /// "Cihazı adlandır". Kutu kullanıcının **kendi** verdiği adla açılıyor;
  /// türetilmiş ad konsaydı kendisi yazmış sanırdı.
  Future<void> rename() async {
    final deviceId = detail.session.deviceId;
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

  /// Onay ister, kapatır ve `true` ile döner.
  Future<void> revoke() async {
    if (isWorking) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Oturumu kapat',
      message:
          '"${detail.session.displayName}" cihazındaki oturum kapatılacak. '
          'O cihaz yeniden giriş yapmak zorunda kalacak.',
      actionLabel: 'Kapat',
    );

    if (confirmed != true || !mounted) return;
    setState(() => isWorking = true);

    try {
      await _service.revoke(detail.session.id);
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
