import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/features/account/presentation/widgets/account_list_clearance.dart';
import 'package:koala/product/models/session_detail.dart';
import 'package:koala/product/models/user_session.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/session_service.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/reason_dialog.dart';
import 'package:koala/product/widgets/settings_hint.dart';

part 'session_detail_pagemodel.dart';

/// Tek bir oturumun ayrıntısı: cihaz, IP, yaklaşık konum, zamanlar, giriş
/// sayısı ve son girişler; altında "Cihazı adlandır" ve "Oturumu kapat".
///
/// Sayfa yüklenmiş bir [SessionDetail] ile açılıyor — liste ayrıntıyı önce
/// kendisi çekiyor, çünkü eski sunucu ucu tanımıyor ve `404`'ü listede
/// yutmak boş bir sayfa açmaktan iyi. Aşağı çekince yeniden okunuyor.
/// Oturum kapatılınca `true` ile kapanır; liste bunu görüp yenileniyor.
class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({super.key, required this.initial, this.service});

  /// Listenin çektiği ayrıntı; sayfa bununla açılıyor.
  final SessionDetail initial;

  /// Testlerde sahte sunucuya bağlı örnek geçilebilsin diye.
  final SessionService? service;

  /// Sunucu konum çıkaramadığında (ve IP gibi boş gelen her alanda)
  /// yazılan tire.
  static const String missing = '—';

  /// Giriş geçmişi boşken yazılan not: sunucu girişleri 0.9.28'den beri
  /// kaydediyor, o günden önceki girişler listede yok.
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
    return Row(
      children: [
        Container(
          width: AppSizes.iconTile,
          height: AppSizes.iconTile,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.accentColor.withValues(
              alpha: AppColors.surfaceTintAlpha,
            ),
            borderRadius: AppRadius.innerCircular,
          ),
          child: AppIcon(
            _deviceIcon(detail.deviceType),
            size: AppSizes.icon,
            color: context.accentColor,
          ),
        ),
        const SizedBox(width: AppSizes.space),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.displayName,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.spaceTiny),
              Text(
                detail.deviceType.displayName,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.textTertiary,
                ),
              ),
            ],
          ),
        ),
        if (detail.isCurrent) ...[
          const SizedBox(width: AppSizes.spaceSmall),
          _currentBadge(),
        ],
      ],
    );
  }

  Widget _currentBadge() {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: AppColors.surfaceTintAlpha),
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

  Widget _infoCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        children: [
          _infoRow('IP adresi', _text(detail.ipAddress)),
          _infoRow('Konum', _locationText(detail.location)),
          _infoRow('Oluşturulma', _dateText(detail.createdAt)),
          _infoRow('Son erişim', _dateText(detail.lastAccessedAt)),
          _infoRow('Süre sonu', _dateText(detail.refreshExpiresAt)),
          _infoRow('Toplam giriş', '${detail.logins}', last: true),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool last = false}) {
    return Container(
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.dividerColor, width: 1),
              ),
            ),
      child: Padding(
        padding: AppPadding.tile,
        child: Row(
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
        ),
      ),
    );
  }

  /// Adlandırma cihaz kimliği olmadan yapılamıyor; kendi oturumunu kapatmak
  /// çıkış yapmak demek — o iş ayarlardaki "Çıkış Yap"a ait, listede olduğu
  /// gibi burada da düğme çizilmiyor.
  Widget _actions() {
    final canRename = detail.deviceId != null;
    final canRevoke = !detail.isCurrent;
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
    if (detail.loginHistory.isEmpty) {
      return const SettingsHint(
        SessionDetailPage.emptyHistoryNote,
        padding: EdgeInsets.zero,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        children: [
          for (final (index, entry) in detail.loginHistory.indexed)
            _historyRow(entry, last: index == detail.loginHistory.length - 1),
        ],
      ),
    );
  }

  Widget _historyRow(LoginHistoryEntry entry, {required bool last}) {
    final where = [
      _text(entry.ipAddress),
      _locationText(entry.location),
    ].join(' · ');

    return Container(
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.dividerColor, width: 1),
              ),
            ),
      child: Padding(
        padding: AppPadding.tile,
        child: Row(
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
            _outcomeBadge(entry.successful),
          ],
        ),
      ),
    );
  }

  Widget _outcomeBadge(bool successful) {
    final color = successful ? AppColors.success : AppColors.danger;

    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        successful ? 'Başarılı' : 'Başarısız',
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static String _text(String? value) => value != null && value.trim().isNotEmpty
      ? value
      : SessionDetailPage.missing;

  /// Konum IP'den çıkarılıyor; "Yaklaşık" demek, kullanıcının şehri değil
  /// sağlayıcının çıkış noktası olabileceğini söylüyor.
  static String _locationText(String? location) =>
      location != null && location.trim().isNotEmpty
      ? 'Yaklaşık: $location'
      : SessionDetailPage.missing;

  static String _dateText(DateTime? value) =>
      value?.toLocal().asShortDateTime ?? SessionDetailPage.missing;

  AppIconData _deviceIcon(SessionDeviceType type) {
    return switch (type) {
      SessionDeviceType.ios || SessionDeviceType.android => AppIcons.mobile,
      SessionDeviceType.webBrowser => AppIcons.globe,
      SessionDeviceType.other || SessionDeviceType.unknown => AppIcons.shield,
    };
  }
}
