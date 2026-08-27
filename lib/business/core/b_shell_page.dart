import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/core/widgets/b_nav_item.dart';
import 'package:koala/business/features/home/presentation/providers/b_page_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:provider/provider.dart';

class BShellPage extends StatelessWidget {
  final Widget child;

  const BShellPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BPageProvider(),
      child: Consumer<BPageProvider>(
        builder: (context, pageProvider, _) {
          final currentLocation = GoRouterState.of(context).matchedLocation;

          return Scaffold(
            extendBodyBehindAppBar: true,
            extendBody: true,
            body: child,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navShadow,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: AppPadding.bNavBarPadding.copyWith(
                  bottom: context.padding.bottom,
                ),
                child: SizedBox(
                  height: AppSizes.bNavBar,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: BNavItem(
                          index: 0,
                          label: 'Ana Sayfa',
                          isSelected: currentLocation == '/business/home',
                          onTap: () => context.go('/business/home'),
                          icon: AppIcons.home,
                        ),
                      ),
                      Expanded(
                        child: BNavItem(
                          index: 1,
                          label: 'İlanlar',
                          isSelected: currentLocation == '/business/posts',
                          onTap: () => context.go('/business/posts'),
                          icon: AppIcons.work,
                        ),
                      ),
                      Expanded(
                        child: BNavItem(
                          index: 2,
                          isSelected: currentLocation == '/business/create',
                          onTap: () => context.push('/business/create'),
                          icon: AppIcons.plus,
                          centerItem: true,
                        ),
                      ),
                      Expanded(
                        child: BNavItem(
                          index: 3,
                          label: 'Sohbetler',
                          isSelected: currentLocation == '/business/chat',
                          onTap: () => context.go('/business/chat'),
                          icon: AppIcons.chat,
                        ),
                      ),

                      Expanded(
                        child: BNavItem(
                          index: 4,
                          label: 'Profil',
                          isSelected: currentLocation == '/business/profile',
                          onTap: () => context.go('/business/profile'),
                          icon: AppIcons.user,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
