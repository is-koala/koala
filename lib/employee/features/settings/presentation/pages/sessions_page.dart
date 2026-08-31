import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/models/user_session.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/session_service.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';

/// Hesaba giriş yapılmış cihazlar.
///
/// Hesap düzeyinde bir ekran, uygulamaya özel değil — iki taraf da aynı
/// yola (`/sessions`) gidiyor.
class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final SessionService _service = SessionService();

  /// Cihaz ikonunu taşıyan kutu.
  static const double _iconBox = 44;

  /// İkon kutusunun zemin tonu.
  static const double _iconTintAlpha = 0.12;

  List<UserSession> _sessions = const [];
  bool _isLoading = true;
  bool _isWorking = false;
  String? _errorMessage;

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

  Future<void> _revoke(UserSession session) async {
    final confirmed = await _confirm(
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
    final confirmed = await _confirm(
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

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String actionLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.secondaryCircular,
        ),
        title: Text(title, style: dialogContext.textTheme.titleMedium),
        content: Text(
          message,
          style: dialogContext.textTheme.bodyMedium?.copyWith(
            color: dialogContext.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(
        title: 'Oturumlar',
        actions: [
          if (_others.isNotEmpty)
            TextButton(
              onPressed: _isWorking ? null : _revokeOthers,
              child: Text(
                'Diğerlerini Kapat',
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ),
        ],
      ),
      body: _body(),
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
              padding: const EdgeInsets.only(
                top: AppSizes.spaceSmall,
                bottom: AppSizes.space,
              ),
              itemCount: _sessions.length,
              itemBuilder: (context, index) => _tile(_sessions[index]),
            ),
    );
  }

  Widget _tile(UserSession session) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.dividerColor, width: 1),
        ),
      ),
      child: Padding(
        padding: AppPadding.tileTall,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: _iconBox,
              height: _iconBox,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: _iconTintAlpha),
                borderRadius: AppRadius.innerCircular,
              ),
              child: AppIcon(
                _deviceIcon(session.deviceType),
                size: AppSizes.icon,
                color: context.accentColor,
              ),
            ),
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
          ],
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
              _currentBadge(),
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

  Widget _currentBadge() {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: _iconTintAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        'Bu cihaz',
        style: context.textTheme.labelSmall?.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w600,
        ),
      ),
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

  AppIconData _deviceIcon(SessionDeviceType type) {
    return switch (type) {
      SessionDeviceType.ios || SessionDeviceType.android => AppIcons.mobile,
      SessionDeviceType.webBrowser => AppIcons.globe,
      SessionDeviceType.other || SessionDeviceType.unknown => AppIcons.shield,
    };
  }
}
