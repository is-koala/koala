import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/features/account/account_routes.dart';
import 'package:koala/product/models/user_session.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/session_service.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/session_device_icon.dart';
import 'package:koala/product/widgets/status_badge.dart';

/// Hesaba giriş yapılmış cihazların listesi.
///
/// Ekranın kendisi değil gövdesi: `Scaffold` ve başlık çubuğu çağırana ait,
/// çünkü iki uygulamanın başlık çubuğu farklı kuruluyor —
/// [NotificationView] ile aynı düzen.
class SessionView extends StatefulWidget {
  const SessionView({
    super.key,
    this.bottomPadding = AppSizes.space,
    this.service,
  });

  /// Listenin altındaki boşluk. İşveren tarafında navbar'ın altında
  /// kalmasın diye büyütülüyor.
  final double bottomPadding;

  /// Testlerde sahte sunucuya bağlı örnek geçilebilsin diye.
  final SessionService? service;

  @override
  State<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<SessionView> {
  late final SessionService _service = widget.service ?? SessionService();

  List<UserSession> _sessions = const [];
  bool _isLoading = true;
  bool _isWorking = false;
  String? _errorMessage;

  /// Sunucu oturum ayrıntısını veriyor mu.
  ///
  /// Ayrıntı ucu 0.9.28 ile geldi; eski sunucu `404` döndürüyor. İlk `404`
  /// ekran boyunca akılda tutuluyor ve satırlar dokunulmaz oluyor: her
  /// dokunuşta aynı `404`'ü alıp sessiz kalmak, kullanıcıya bozuk bir düğme
  /// gibi görünürdü. Baştan "var" sayılıyor; bir istek atmadan bilmenin yolu
  /// yok.
  bool _detailAvailable = true;

  /// Ayrıntısı şu anda çekilen oturum; aynı satıra ikinci dokunuş beklemiyor.
  String? _openingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Kullanıcının kendi cihazı dışındaki oturumlar.
  Iterable<UserSession> get _others =>
      _sessions.where((session) => !session.isCurrent);

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final sessions = await _service.fetchSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Kapatma çağrılarının ortak gövdesi.
  ///
  /// Liste sunucudan yeniden çekiliyor, elde silinmiyor: kapatılan oturum
  /// bir başkasını da düşürmüş olabilir.
  Future<void> _run(
    Future<void> Function() call, {
    required String successMessage,
  }) async {
    if (_isWorking) return;
    setState(() => _isWorking = true);

    try {
      await call();
      await _load(silent: true);
      if (mounted) AppToast.success(context, successMessage);
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  /// Satıra dokununca ayrıntıyı çekip sayfayı açar.
  ///
  /// Ayrıntı önce burada çekiliyor, sayfada değil: eski sunucunun `404`'ü
  /// boş bir sayfa yerine burada yutuluyor — toast yok, satır bundan sonra
  /// dokunulmuyor. Aynı `404` bu arada kapanmış bir oturum için de gelir;
  /// liste sessizce yenilenip oturum hâlâ duruyorsa "sunucu ucu tanımıyor"
  /// sayılıyor, düşmüşse yalnızca liste güncellenmiş oluyor.
  Future<void> _openDetail(UserSession session) async {
    if (_openingId != null || !_detailAvailable) return;
    setState(() => _openingId = session.id);

    try {
      final detail = await _service.fetchDetail(session.id);
      if (!mounted) return;
      final revoked = await context.push<bool>(
        AccountRoutes.sessionDetail,
        extra: detail,
      );
      if (revoked == true && mounted) await _load(silent: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.type == ApiErrorType.notFound) {
        await _load(silent: true);
        if (!mounted) return;
        final stillListed = _sessions.any((row) => row.id == session.id);
        if (stillListed) setState(() => _detailAvailable = false);
        return;
      }
      AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  Future<void> _revoke(UserSession session) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Oturumu kapat',
      message:
          '"${session.displayName}" cihazındaki oturum kapatılacak. '
          'O cihaz yeniden giriş yapmak zorunda kalacak.',
      actionLabel: 'Kapat',
    );

    if (confirmed != true) return;

    await _run(
      () => _service.revoke(session.id),
      successMessage: 'Oturum kapatıldı',
    );
  }

  Future<void> _revokeOthers() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Diğer cihazlardan çık',
      message:
          'Bu cihaz dışındaki bütün oturumlar kapatılacak. '
          'Kendi oturumunuz açık kalacak.',
      actionLabel: 'Hepsini Kapat',
    );

    if (confirmed != true) return;

    await _run(
      _service.revokeOthers,
      successMessage: 'Diğer oturumlar kapatıldı',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Eylem başlık çubuğunda değil listenin üstünde: gövde iki ayrı
        // ekranda kullanılıyor ve durum burada duruyor, çubuğa taşımak
        // sayfaları kalınlaştırırdı.
        ?_revokeOthersBar(),
        Expanded(child: _body()),
      ],
    );
  }

  Widget? _revokeOthersBar() {
    if (_others.isEmpty) return null;

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: AppPadding.horizontalSmall,
        child: TextButton(
          onPressed: _isWorking ? null : _revokeOthers,
          child: Text(
            'Diğer Cihazlardan Çık',
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.danger,
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_isLoading && _sessions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sessions.isEmpty && _errorMessage != null) {
      return EmptyState(
        icon: AppIcons.alert,
        title: 'Oturumlar açılamadı',
        description: _errorMessage!,
        action: TextButton(onPressed: _load, child: const Text('Tekrar Dene')),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: _sessions.isEmpty
          ? const EmptyState(
              icon: AppIcons.mobile,
              title: 'Açık oturum yok',
              description: 'Giriş yapılmış bir cihaz görünmüyor.',
            )
          : ListView.builder(
              padding: EdgeInsets.only(
                top: AppSizes.spaceSmall,
                bottom: widget.bottomPadding,
              ),
              itemCount: _sessions.length,
              itemBuilder: (context, index) => _tile(_sessions[index]),
            ),
    );
  }

  Widget _tile(UserSession session) {
    final canOpen = _detailAvailable && _openingId == null;

    return Container(
      key: ValueKey('session-${session.id}'),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.dividerColor,
            width: AppSizes.divider,
          ),
        ),
      ),
      child: InkWell(
        onTap: canOpen ? () => _openDetail(session) : null,
        child: Padding(
          padding: AppPadding.tileTall,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SessionDeviceIcon(session.deviceType),
              const SizedBox(width: AppSizes.space),
              Expanded(child: _tileContent(session)),
              // Kendi oturumunu kapatmak çıkış yapmak demek; o iş ayarlardaki
              // "Çıkış Yap"a ait, burada düğme çizilmiyor.
              if (!session.isCurrent)
                IconButton(
                  onPressed: _isWorking ? null : () => _revoke(session),
                  icon: const AppIcon(
                    AppIcons.logout,
                    color: AppColors.danger,
                    size: AppSizes.iconMedium,
                  ),
                ),
              // Ok yalnız ayrıntı açılabiliyorsa: eski sunucuda satır düz bir
              // satır, gidilecek yeri yokmuş gibi görünmeli.
              if (_detailAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: AppSizes.space),
                  child: AppIcon(
                    AppIcons.arrowRight,
                    size: AppSizes.iconSmall,
                    color: context.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tileContent(UserSession session) {
    final subtitle = _subtitle(session);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                session.displayName,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (session.isCurrent) ...[
              const SizedBox(width: AppSizes.spaceSmall),
              const CurrentSessionBadge(),
            ],
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: AppSizes.spaceTiny),
          Text(
            subtitle,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  /// Yer ve son kullanım. İkisi de boş gelebiliyor, o zaman satır hiç
  /// çizilmiyor — "null · null" göstermektense boş bırakmak iyi.
  String _subtitle(UserSession session) {
    final parts = <String>[
      if (session.location != null && session.location!.trim().isNotEmpty)
        session.location!,
      if (session.lastAccessedAt != null) session.lastAccessedAt!.asRelative,
    ];

    return parts.join(' · ');
  }
}
