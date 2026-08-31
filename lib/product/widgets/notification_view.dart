import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/models/app_notification.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:provider/provider.dart';

/// Bildirim listesinin gövdesi. İki uygulama da aynı listeyi gösteriyor,
/// yalnızca alt boşlukları farklı.
///
/// Ekranın kendisi değil gövdesi: `Scaffold` ve başlık çubuğu çağırana ait,
/// çünkü iki tarafın başlık çubuğu farklı kuruluyor.
///
/// TODO(backend): Sunucu bir olay için hem push hem e-posta kaydı yazıyor
/// ve akış ikisini de döndürüyor, yani bildirimler ileride çift görünecek.
/// Bugün görünmüyor: push kaydı yalnızca kullanıcının push token'ı olan bir
/// cihazı varsa yazılıyor, uygulama da henüz token göndermiyor. Kanal
/// ayrımı sunucuda çözülecek — burada süzme yapılmadı, çünkü `IN_APP`
/// kanalı eklenirse süzgeç yanlış tarafa düşerdi.
class NotificationView extends StatefulWidget {
  const NotificationView({super.key, this.bottomPadding = AppSizes.space});

  /// Listenin altındaki boşluk. İşveren tarafında navbar'ın altında
  /// kalmaması için büyütülüyor.
  final double bottomPadding;

  @override
  State<NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<NotificationView> {
  final ScrollController _controller = ScrollController();

  /// Listenin sonuna bu kadar kala sonraki sayfa isteniyor; kullanıcı dibe
  /// değmeden yükleme başlasın.
  static const double _loadMoreThreshold = 240;

  /// Okunmamış satırın zemin vurgusu; renk değil ton farkı olsun diye çok
  /// düşük opaklık.
  static const double _unreadTintAlpha = 0.04;

  /// Kategori ikonunu taşıyan renkli kutu.
  static const double _iconBox = 44;

  /// İkon kutusunun zemin tonu.
  static const double _iconTintAlpha = 0.12;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().load();
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;

    final remaining =
        _controller.position.maxScrollExtent - _controller.position.pixels;

    if (remaining <= _loadMoreThreshold) {
      context.read<NotificationProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    if (provider.isLoading && provider.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.notifications.isEmpty && provider.errorMessage != null) {
      return _errorState(provider.errorMessage!);
    }

    return RefreshIndicator(
      onRefresh: () => context.read<NotificationProvider>().load(silent: true),
      child: provider.notifications.isEmpty
          ? const EmptyState(
              icon: AppIcons.notification,
              title: 'Bildirim yok',
              description: 'Yeni bildirimler geldiğinde burada görünecek.',
            )
          : ListView.builder(
              controller: _controller,
              padding: EdgeInsets.only(
                top: AppSizes.spaceSmall,
                bottom: widget.bottomPadding,
              ),
              itemCount:
                  provider.notifications.length + (provider.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= provider.notifications.length) {
                  return const Padding(
                    padding: AppPadding.primaryAll,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                return _tile(provider.notifications[index]);
              },
            ),
    );
  }

  Widget _errorState(String message) {
    return EmptyState(
      icon: AppIcons.alert,
      title: 'Bildirimler açılamadı',
      description: message,
      action: TextButton(
        onPressed: () => context.read<NotificationProvider>().load(),
        child: const Text('Tekrar Dene'),
      ),
    );
  }

  Widget _tile(AppNotification notification) {
    final style = _categoryStyle(notification.category);

    return Container(
      decoration: BoxDecoration(
        color: notification.isRead
            ? context.backgroundColor
            : context.accentColor.withValues(alpha: _unreadTintAlpha),
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
              // Hizasız `Container` çocuğuna tight constraint geçiriyor ve
              // `AppIcon` kendi ölçüsünü isteyemeden kutuyu dolduruyor.
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: _iconTintAlpha),
                borderRadius: AppRadius.innerCircular,
              ),
              child: AppIcon(
                style.icon,
                size: AppSizes.iconMedium,
                color: style.color,
              ),
            ),
            const SizedBox(width: AppSizes.space),
            Expanded(child: _tileContent(notification)),
          ],
        ),
      ),
    );
  }

  Widget _tileContent(AppNotification notification) {
    final subtitle = _subtitle(notification);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                // Konu boş gelebiliyor; o zaman hiç değilse neyle ilgili
                // olduğu görünsün.
                notification.hasSubject
                    ? notification.subject!
                    : notification.category.displayName,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: notification.isRead
                      ? FontWeight.w500
                      : FontWeight.w600,
                ),
              ),
            ),
            if (!notification.isRead)
              Container(
                width: AppSizes.badgeDot,
                height: AppSizes.badgeDot,
                decoration: BoxDecoration(
                  color: context.accentColor,
                  shape: BoxShape.circle,
                ),
              ),
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

  /// Kategori adı ve zaman. Sunucu bildirimin gövdesini yanıta çıkarmıyor,
  /// o yüzden satırın ikinci katı bağlamla dolduruluyor.
  ///
  /// Konu boşsa kategori zaten başlığa geçmiş oluyor; burada tekrarlanmıyor.
  String _subtitle(AppNotification notification) {
    final sentAt = notification.sentAt;

    if (!notification.hasSubject) {
      return sentAt == null ? '' : sentAt.asRelative;
    }

    final category = notification.category.displayName;

    return sentAt == null ? category : '$category · ${sentAt.asRelative}';
  }

  _CategoryStyle _categoryStyle(NotificationCategory category) {
    return switch (category) {
      NotificationCategory.accountSecurity => _CategoryStyle(
        AppIcons.shield,
        context.accentColor,
      ),
      NotificationCategory.applicationUpdates => _CategoryStyle(
        AppIcons.work,
        context.accentColor,
      ),
      NotificationCategory.identityVerification => _CategoryStyle(
        AppIcons.userCheck,
        context.accentColor,
      ),
      NotificationCategory.marketings => _CategoryStyle(
        AppIcons.star,
        context.textSecondary,
      ),
      NotificationCategory.companyUpdates => _CategoryStyle(
        AppIcons.building,
        context.textSecondary,
      ),
      NotificationCategory.jobAlerts => _CategoryStyle(
        AppIcons.alert,
        context.accentColor,
      ),
      NotificationCategory.newsletter => _CategoryStyle(
        AppIcons.mail,
        context.textSecondary,
      ),
      NotificationCategory.other => _CategoryStyle(
        AppIcons.notification,
        context.textSecondary,
      ),
    };
  }
}

class _CategoryStyle {
  const _CategoryStyle(this.icon, this.color);

  final AppIconData icon;
  final Color color;
}

/// Başlık çubuğundaki "Tümünü Oku" eylemi.
///
/// Okunmamış yokken hiç çizilmiyor: basıldığında hiçbir şey yapmayan bir
/// düğme, kullanıcıya işin yürümediğini düşündürüyor.
class MarkAllReadAction extends StatelessWidget {
  const MarkAllReadAction({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    if (!provider.hasUnread) return const SizedBox.shrink();

    return TextButton(
      onPressed: provider.isMarkingRead
          ? null
          : () => context.read<NotificationProvider>().markAllRead(),
      child: Text(
        'Tümünü Oku',
        style: context.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.accentColor,
        ),
      ),
    );
  }
}
