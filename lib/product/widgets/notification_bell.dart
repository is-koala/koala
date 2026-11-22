import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:provider/provider.dart';

/// Bildirim ekranını açan zil; rozet okunmamış varken çizilir. Akış `IN_APP`'e
/// süzüldüğü için sayı gerçek.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.route, this.color});

  /// İki uygulamanın bildirim ekranı ayrı.
  final String route;

  final Color? color;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  static const int _maxBadgeCount = 99;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.select<NotificationProvider, int>(
      (provider) => provider.unreadCount,
    );

    final icon = AppIcon(
      AppIcons.notification,
      color: widget.color ?? context.textSecondary,
      size: AppSizes.icon,
    );

    return IconButton(
      onPressed: () => context.push(widget.route),
      icon: unreadCount == 0
          ? icon
          : Badge(
              // Üç haneli sayı rozeti taşırıyor; "çok" bilgisi yetiyor.
              label: Text(
                unreadCount > _maxBadgeCount
                    ? '$_maxBadgeCount+'
                    : '$unreadCount',
              ),
              backgroundColor: AppColors.danger,
              child: icon,
            ),
    );
  }
}
