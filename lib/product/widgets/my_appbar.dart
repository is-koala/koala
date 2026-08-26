import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

class MyAppbar extends StatelessWidget implements PreferredSizeWidget {
  const MyAppbar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.isLarge = false,
  });

  final String title;
  final bool showBackButton;
  final List<Widget>? actions;

  /// Başlık bir tık büyük çizilsin mi.
  ///
  /// Sekme kökü olan sayfalar (Profilim, Ayarlar, Sohbetler) alt sayfalardan
  /// ayrışsın diye büyük başlık kullanıyor.
  final bool isLarge;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Zemin, gölge ve başlık stili appBarTheme'den geliyor; burada yalnızca
    // sayfaya özgü olanlar veriliyor.
    return AppBar(
      leading: showBackButton
          ? IconButton(
              icon: Icon(
                HugeIcons.strokeRoundedArrowLeft01,
                color: context.textPrimary,
                size: AppSizes.icon,
              ),
              onPressed: () => context.pop(),
            )
          : null,
      automaticallyImplyLeading: false,
      title: Text(
        title,
        style: isLarge
            ? context.theme.appBarTheme.titleTextStyle?.copyWith(
                fontSize: context.textTheme.headlineMedium?.fontSize,
              )
            : null,
      ),
      actions: actions,
    );
  }
}
