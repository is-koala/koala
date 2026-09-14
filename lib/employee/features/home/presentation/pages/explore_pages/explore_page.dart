import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:koala/employee/features/home/presentation/providers/page_provider.dart';
import 'package:koala/employee/features/home/presentation/pages/explore_pages/map_explore_page.dart';
import 'package:koala/employee/features/home/presentation/pages/explore_pages/list_explore_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with AutomaticKeepAliveClientMixin<ExplorePage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Sağlayıcı listeyle başlıyorsa (harita bu derlemede yok) ilk kare de
    // liste olsun; aşağıdaki kare-sonrası atlama yalnız sonraki geçişler için.
    _pageController = PageController(
      initialPage:
          context.read<PageProvider>().exploreViewType == ExploreViewType.map
          ? 0
          : 1,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<PageProvider>(
      builder: (context, pageProvider, child) {
        // PageProvider değiştiğinde sayfa animasyonu yap
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(
              pageProvider.exploreViewType == ExploreViewType.map ? 0 : 1,
            );
          }
        });

        return PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [MapExplorePage(), ListExplorePage()],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
