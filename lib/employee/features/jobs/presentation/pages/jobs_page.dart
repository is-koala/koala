import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:koala/employee/features/home/presentation/providers/page_provider.dart';
import 'package:koala/employee/features/jobs/presentation/pages/my_jobs_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/saved_jobs_page.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage>
    with AutomaticKeepAliveClientMixin<JobsPage> {
  late PageController _pageController;

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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<PageProvider>(
      builder: (context, pageProvider, child) {
        // PageProvider değiştiğinde sayfa animasyonu yap
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(
              pageProvider.jobsViewType == JobsViewType.home ? 0 : 1,
            );
          }
        });

        return PageView(
          controller: _pageController,
          physics:
              const NeverScrollableScrollPhysics(), // Sadece programmatik geçiş
          children: const [MyJobsPage(), SavedJobsPage()],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
