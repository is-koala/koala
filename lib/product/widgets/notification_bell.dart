import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:provider/provider.dart';

/// Bildirim ekranını açan zil. Rozet yalnızca okunmamış varken çiziliyor.
///
/// Sayı gösteriliyor: akış `IN_APP` kanalına süzüldüğünden bir olay bir
/// kayıt, yani sayı gerçek. (Kanal ayrımı gelmeden önce sunucu olay başına
/// birden fazla kayıt yazdığı için burada yalnızca nokta vardı.)
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.route, this.color});

  /// Basılınca gidilecek yol; iki uygulamanın bildirim ekranı ayrı.
  final String route;

  /// Zilin rengi. Verilmezse ikincil metin rengi kullanılıyor.
  final Color? color;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  /// Rozette yazılabilecek en büyük sayı; üstü "99+" oluyor.
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
              // Üç haneli sayı rozeti taşırıyor; okunmamışın kaç tane
              // olduğu değil, çok olduğu bilgisi yetiyor.
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
