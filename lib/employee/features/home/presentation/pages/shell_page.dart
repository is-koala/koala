import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/chat/presentation/pages/chat_list_page.dart';
import 'package:koala/employee/features/home/presentation/pages/explore_pages/explore_page.dart';
import 'package:koala/employee/features/home/presentation/providers/page_provider.dart';
import 'package:koala/employee/features/jobs/presentation/pages/jobs_page.dart';
import 'package:koala/employee/features/profile/presentation/pages/profile_page.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/navbar_item.dart';
import 'package:provider/provider.dart';

class ShellPage extends StatefulWidget {
  final Widget child;

  const ShellPage({super.key, required this.child});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _selectedIndex = 0;
  late PageController _pageController;

  // State korunması için sayfaları burada tanımla
  static const List<Widget> _pages = [
    ExplorePage(),
    JobsPage(),
    ChatListPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index, String path) {
    if (index == 0) {
      // Home butonuna basıldığında
      final pageProvider = Provider.of<PageProvider>(context, listen: false);

      if (_selectedIndex != 0) {
        // Diğer sayfalardan home'a geliyorsa -> map göster
        pageProvider.setExploreViewToMap();
      } else {
        // Zaten home'dayken tekrar basıldıysa -> toggle yap
        pageProvider.toggleExploreView();
      }
    }

    if (index == 1) {
      // Jobs butonuna basıldığında
      final pageProvider = Provider.of<PageProvider>(context, listen: false);

      if (_selectedIndex != 1) {
        // Diğer sayfalardan jobs'a geliyorsa -> home göster
        pageProvider.setJobsViewType(JobsViewType.home);
      } else {
        // Zaten jobs'dayken tekrar basıldıysa -> toggle yap
        pageProvider.toggleJobsView();
      }
    }

    setState(() {
      _selectedIndex = index;
    });

    // PageView'i animasyon olmadan değiştir
    _pageController.jumpToPage(index);

    context.go(path);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // URL'e göre index'i güncelle
    final location = GoRouterState.of(context).matchedLocation;
    int newIndex = 0;
    switch (location) {
      case '/explore':
        newIndex = 0;
        break;
      case '/jobs':
        newIndex = 1;
        break;
      case '/chat':
        newIndex = 2;
        break;
      case '/profile':
        newIndex = 3;
        break;
    }

    if (_selectedIndex != newIndex) {
      setState(() {
        _selectedIndex = newIndex;
      });

      // PageController'ı güncelle
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          newIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          // PageView ile sayfaları yönet
          PageView(
            controller: _pageController,
            physics:
                const NeverScrollableScrollPhysics(), // Sadece programmatik geçiş
            children: _pages,
          ),
          // Sayfanın altında beyaz fade efekti
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              // Listenin son satırı navbar'ın altına girerken sertçe
              // kesilmesin diye sayfanın altına zemine giden bir geçiş.
              child: Container(
                height: AppSizes.navBar,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.backgroundColor.withValues(alpha: 0.0),
                      context.backgroundColor.withValues(alpha: 0.4),
                      context.backgroundColor,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: AppPadding.bottomNavBarPadding,
        child: Center(
          heightFactor: 1.0,
          child: SizedBox(
            width: AppSizes.navBarWidth,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.stadiumCircular,
                color: context.accentColor,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navShadow,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: AppPadding.navBarContent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    NavItem(
                      index: 0,
                      unSelectedIcon: _selectedIndex == 0
                          ? (context.watch<PageProvider>().exploreViewType ==
                                    ExploreViewType.map
                                ? AppIcons.navigation
                                : AppIcons.menu)
                          : AppIcons.navigation,
                      selectedIcon: _selectedIndex == 0
                          ? (context.watch<PageProvider>().exploreViewType ==
                                    ExploreViewType.map
                                ? AppIcons.navigation
                                : AppIcons.menu)
                          : AppIcons.navigation,
                      isSelected: _selectedIndex == 0,
                      onTap: () => _onItemTapped(0, '/explore'),
                    ),
                    NavItem(
                      index: 1,
                      unSelectedIcon: _selectedIndex == 1
                          ? (context.watch<PageProvider>().jobsViewType ==
                                    JobsViewType.home
                                ? AppIcons.work
                                : AppIcons.bookmark)
                          : AppIcons.work,
                      selectedIcon: _selectedIndex == 1
                          ? (context.watch<PageProvider>().jobsViewType ==
                                    JobsViewType.home
                                ? AppIcons.work
                                : AppIcons.bookmark)
                          : AppIcons.work,
                      isSelected: _selectedIndex == 1,
                      onTap: () => _onItemTapped(1, '/jobs'),
                    ),
                    NavItem(
                      index: 2,
                      unSelectedIcon: AppIcons.chat,
                      selectedIcon: AppIcons.chat,
                      isSelected: _selectedIndex == 2,
                      onTap: () => _onItemTapped(2, '/chat'),
                    ),
                    NavItem(
                      index: 3,
                      unSelectedIcon: AppIcons.user,
                      selectedIcon: AppIcons.user,
                      isSelected: _selectedIndex == 3,
                      onTap: () => _onItemTapped(3, '/profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
