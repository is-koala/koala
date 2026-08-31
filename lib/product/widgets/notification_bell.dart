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
/// Sayı yazılmıyor, nokta gösteriliyor: sunucu bugün bir olay için birden
/// fazla kayıt üretebildiğinden sayı olduğundan büyük çıkabilir. Nokta
/// "yeni bir şey var" demeye yetiyor ve yanlış sayı göstermiyor.
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = context.select<NotificationProvider, bool>(
      (provider) => provider.hasUnread,
    );

    final icon = AppIcon(
      AppIcons.notification,
      color: widget.color ?? context.textSecondary,
      size: AppSizes.icon,
    );

    return IconButton(
      onPressed: () => context.push(widget.route),
      icon: hasUnread
          ? Badge(
              smallSize: AppSizes.badgeDot,
              backgroundColor: AppColors.danger,
              child: icon,
            )
          : icon,
    );
  }
}
