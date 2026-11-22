import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/features/account/presentation/widgets/account_list_clearance.dart';
import 'package:koala/product/models/session_detail.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/session_service.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/reason_dialog.dart';
import 'package:koala/product/widgets/session_device_icon.dart';
import 'package:koala/product/widgets/settings_hint.dart';
import 'package:koala/product/widgets/status_badge.dart';

part 'session_detail_pagemodel.dart';

/// Oturum ayrıntısı ve "Cihazı adlandır" / "Oturumu kapat". Yüklenmiş
/// [SessionDetail] ile açılır; kapatılınca `true` ile döner.
class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({super.key, required this.initial, this.service});

  final SessionDetail initial;

  final SessionService? service;

  static const String missing = '—';

  /// Sunucu girişleri yakın zamandan beri kaydediyor; öncekiler listede yok.
  static const String emptyHistoryNote =
      'Geçmiş, güncellemeden sonraki girişleri kapsar.';

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends SessionDetailPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Oturum'),
      body: RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppPadding.primary,
            AppSizes.spaceSmall,
            AppPadding.primary,
            AccountListClearance.bottomPadding(),
          ),
          children: [
            _header(),
            const SizedBox(height: AppSizes.spaceMedium),
            _infoCard(),
            const SizedBox(height: AppSizes.spaceMedium),
            _actions(),
            _sectionTitle('Giriş geçmişi'),
            _history(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final session = detail.session;

    return Row(
      children: [
        SessionDeviceIcon(session.deviceType),
        const SizedBox(width: AppSizes.space),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.displayName,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.spaceTiny),
              Text(
                session.deviceType.displayName,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.textTertiary,
                ),
              ),
            ],
          ),
        ),
        if (session.isCurrent) ...[
          const SizedBox(width: AppSizes.spaceSmall),
          const CurrentSessionBadge(),
        ],
      ],
    );
  }

  Widget _infoCard() {
    final session = detail.session;
    final rows = [
      ('IP adresi', _text(session.ipAddress)),
      ('Konum', _locationText(session.location)),
      ('Oluşturulma', _dateText(detail.createdAt)),
      ('Son erişim', _dateText(session.lastAccessedAt)),
      ('Süre sonu', _dateText(session.refreshExpiresAt)),
      ('Toplam giriş', '${detail.logins}'),
    ];

    return _card([
      for (final (index, (label, value)) in rows.indexed)
        _row(_infoRow(label, value), last: index == rows.length - 1),
    ]);
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.textSecondary,
          ),
        ),
        const SizedBox(width: AppSizes.space),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Kendi oturumunu kapatmak çıkış demek; düğme çizilmiyor.
  Widget _actions() {
    final canRename = detail.session.deviceId != null;
    final canRevoke = !detail.session.isCurrent;
    if (!canRename && !canRevoke) return const SizedBox.shrink();

    return Row(
      children: [
        if (canRename)
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('session-rename'),
              onPressed: isWorking ? null : rename,
              icon: const AppIcon(AppIcons.edit, size: AppSizes.iconSmall),
              label: const Text('Cihazı adlandır'),
            ),
          ),
        if (canRename && canRevoke) const SizedBox(width: AppSizes.space),
        if (canRevoke)
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('session-revoke'),
              onPressed: isWorking ? null : revoke,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              icon: const AppIcon(
                AppIcons.logout,
                size: AppSizes.iconSmall,
                color: AppColors.danger,
              ),
              label: const Text('Oturumu kapat'),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: AppPadding.sectionHeader,
      child: Text(
        title,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _history() {
    final history = detail.loginHistory;
    if (history.isEmpty) {
      return const SettingsHint(
        SessionDetailPage.emptyHistoryNote,
        padding: EdgeInsets.zero,
      );
    }

    return _card([
      for (final (index, entry) in history.indexed)
        _row(_historyRow(entry), last: index == history.length - 1),
    ]);
  }

  Widget _historyRow(LoginHistoryEntry entry) {
    final where = [
      _text(entry.ipAddress),
      _locationText(entry.location),
    ].join(' · ');
    final color = entry.successful ? AppColors.success : AppColors.danger;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dateText(entry.at),
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSizes.spaceTiny),
              Text(
                where,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.space),
        StatusBadge(entry.successful ? 'Başarılı' : 'Başarısız', color: color),
      ],
    );
  }

  Widget _card(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(children: rows),
    );
  }

  Widget _row(Widget child, {required bool last}) {
    return Container(
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.dividerColor,
                  width: AppSizes.divider,
                ),
              ),
            ),
      child: Padding(padding: AppPadding.tile, child: child),
    );
  }

  static String _text(String? value) => value != null && value.trim().isNotEmpty
      ? value
      : SessionDetailPage.missing;

  /// Konum IP'den; "Yaklaşık" sağlayıcının çıkış noktası olabileceğini
  /// söylüyor.
  static String _locationText(String? location) =>
      location != null && location.trim().isNotEmpty
      ? 'Yaklaşık: $location'
      : SessionDetailPage.missing;

  static String _dateText(DateTime? value) =>
      value?.toLocal().asShortDateTime ?? SessionDetailPage.missing;
}
