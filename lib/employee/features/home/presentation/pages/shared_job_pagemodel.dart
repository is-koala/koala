part of 'shared_job_page.dart';

abstract class SharedJobPageModel extends State<SharedJobPage> {
  late final JobService _jobService = widget.jobService ?? JobService();

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final Job job;
    try {
      job = (await _jobService.getById(widget.jobId)).toSummary();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = error.type == ApiErrorType.notFound
            ? 'Bu ilan artık yayında değil ya da bağlantı hatalı.'
            : error.message;
      });
      return;
    }
    if (!mounted) return;

    // Sheet keşfetin üstünde açılır ki kapanınca kullanıcı uygulamada kalsın;
    // bu sayfa `go` ile kalktığı için kök navigator'ın bağlamı.
    final rootNavigator = RouterManager.router.routerDelegate.navigatorKey;
    context.go('/explore');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rootContext = rootNavigator.currentContext;
      if (rootContext != null && rootContext.mounted) {
        JobDetailBottomSheet.show(rootContext, job);
      }
    });
  }

  void openExplore() => context.go('/explore');
}
