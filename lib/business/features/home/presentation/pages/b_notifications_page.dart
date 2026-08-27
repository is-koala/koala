import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/my_appbar.dart';

/// Bildirim türleri
enum BNotificationType { applicant, approved, rejected, info, system }

/// Tek bir bildirim modeli
class _BNotification {
  final String id;
  final String title;
  final String body;
  final BNotificationType type;
  final String timeAgo;
  final bool isRead;

  const _BNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timeAgo,
    this.isRead = false,
  });
}

class BNotificationsPage extends StatefulWidget {
  const BNotificationsPage({super.key});

  @override
  State<BNotificationsPage> createState() => _BNotificationsPageState();
}

class _BNotificationsPageState extends State<BNotificationsPage> {
  /// Boş durum ikonunu taşıyan kutu.
  static const double _emptyIconBox = 80;

  /// Bildirim türünü gösteren renkli ikon kutusu.
  static const double _typeIconBox = 44;

  /// Okunmamış satırın zemin vurgusu; renk değil ton farkı olsun diye çok
  /// düşük opaklık.
  static const double _unreadTintAlpha = 0.04;

  late List<_BNotification> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = _generateFakeNotifications();
  }

  List<_BNotification> _generateFakeNotifications() {
    return const [
      _BNotification(
        id: 'n1',
        title: 'Yeni Başvuru',
        body: 'Yakup Demir, "Part-time Garson" ilanınıza başvurdu.',
        type: BNotificationType.applicant,
        timeAgo: '5 dk önce',
      ),
      _BNotification(
        id: 'n2',
        title: 'Yeni Başvuru',
        body: 'Ayşe Yılmaz, "Deneyimli Barista" ilanınıza başvurdu.',
        type: BNotificationType.applicant,
        timeAgo: '23 dk önce',
      ),
      _BNotification(
        id: 'n3',
        title: 'İlan Onaylandı',
        body: '"Part-time Garson" ilanınız incelendi ve yayına alındı.',
        type: BNotificationType.approved,
        timeAgo: '1 saat önce',
        isRead: true,
      ),
      _BNotification(
        id: 'n4',
        title: 'Yeni Başvuru',
        body: 'Mehmet Kaya, "Deneyimli Barista" ilanınıza başvurdu.',
        type: BNotificationType.applicant,
        timeAgo: '2 saat önce',
        isRead: true,
      ),
      _BNotification(
        id: 'n5',
        title: 'İş Tamamlandı',
        body:
            'Burak Şen, "Mekan Fotoğrafçısı" işini tamamladı. Değerlendirme yapabilirsiniz.',
        type: BNotificationType.info,
        timeAgo: '1 gün önce',
        isRead: true,
      ),
      _BNotification(
        id: 'n6',
        title: 'Sistem Bildirimi',
        body: 'Koala İşveren Paneli güncellendi! Yeni özellikler eklendi.',
        type: BNotificationType.system,
        timeAgo: '2 gün önce',
        isRead: true,
      ),
      _BNotification(
        id: 'n7',
        title: 'İlan Onaylandı',
        body: '"Deneyimli Barista" ilanınız incelendi ve yayına alındı.',
        type: BNotificationType.approved,
        timeAgo: '3 gün önce',
        isRead: true,
      ),
      _BNotification(
        id: 'n8',
        title: 'Hoş Geldiniz!',
        body:
            'Koala İşveren Paneli\'ne hoş geldiniz. İlan oluşturarak hemen başlayabilirsiniz.',
        type: BNotificationType.system,
        timeAgo: '1 hafta önce',
        isRead: true,
      ),
    ];
  }

  void _markAllAsRead() {
    setState(() {
      _notifications = _notifications
          .map(
            (n) => _BNotification(
              id: n.id,
              title: n.title,
              body: n.body,
              type: n.type,
              timeAgo: n.timeAgo,
              isRead: true,
            ),
          )
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tüm bildirimler okundu olarak işaretlendi'),
        backgroundColor: context.accentColor,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.smallCircular,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _dismissNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(
        title: 'Bildirimler',
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Tümünü Oku',
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.accentColor,
                ),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? _emptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(
                top: AppSizes.spaceSmall,
                bottom: AppSizes.navBarClearance,
              ),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _notificationTile(context, notification);
              },
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: _emptyIconBox,
              height: _emptyIconBox,
              decoration: BoxDecoration(
                color: context.tileColor,
                borderRadius: AppRadius.secondaryCircular,
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedNotification03,
                size: AppSizes.iconLarge,
                color: context.dividerColor,
              ),
            ),
            const SizedBox(height: AppSizes.spaceLarge),
            Text(
              'Bildirim yok',
              style: context.textTheme.titleMedium?.copyWith(
                color: context.textTertiary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              'Yeni bildirimler geldiğinde\nburada görünecek.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationTile(BuildContext context, _BNotification notification) {
    final config = _typeConfig(notification.type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _dismissNotification(notification.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSizes.spaceLarge),
        color: AppColors.danger.withValues(alpha: 0.1),
        child: const HugeIcon(
          icon: HugeIcons.strokeRoundedDelete02,
          color: AppColors.danger,
        ),
      ),
      child: Container(
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
              // İkon
              Container(
                width: _typeIconBox,
                height: _typeIconBox,
                decoration: BoxDecoration(
                  color: config.color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.innerCircular,
                ),
                child: HugeIcon(
                  icon: config.icon,
                  size: AppSizes.iconMedium,
                  color: config.color,
                ),
              ),
              const SizedBox(width: AppSizes.space),

              // İçerik
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
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
                    const SizedBox(height: AppSizes.spaceTiny),
                    Text(
                      notification.body,
                      style: context.textTheme.bodySmall?.copyWith(height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.spaceTiny),
                    Text(
                      notification.timeAgo,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _NotificationTypeConfig _typeConfig(BNotificationType type) {
    switch (type) {
      case BNotificationType.applicant:
        return _NotificationTypeConfig(
          icon: HugeIcons.strokeRoundedUserAdd01,
          color: AppColors.info,
        );
      case BNotificationType.approved:
        return _NotificationTypeConfig(
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          color: AppColors.primaryColor,
        );
      case BNotificationType.rejected:
        return _NotificationTypeConfig(
          icon: HugeIcons.strokeRoundedCancelCircle,
          color: AppColors.danger,
        );
      case BNotificationType.info:
        return _NotificationTypeConfig(
          icon: HugeIcons.strokeRoundedInformationCircle,
          color: AppColors.warning,
        );
      case BNotificationType.system:
        return _NotificationTypeConfig(
          icon: HugeIcons.strokeRoundedSettings01,
          color: context.textSecondary,
        );
    }
  }
}

class _NotificationTypeConfig {
  final AppIconData icon;
  final Color color;

  const _NotificationTypeConfig({required this.icon, required this.color});
}
