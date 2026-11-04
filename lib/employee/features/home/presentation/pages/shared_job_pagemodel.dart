part of 'shared_job_page.dart';

abstract class SharedJobPageModel extends State<SharedJobPage> {
  late final JobService _jobService = widget.jobService ?? JobService();

  /// Doluysa ilan açılamadı; sayfa sebebini ve keşfete dönüşü gösteriyor.
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

    // Keşfete geçiliyor, sheet keşfetin üstünde açılıyor: kapanınca kullanıcı
    // boş bir ara sayfada değil, uygulamanın kendisinde kalıyor. Bu sayfa
    // `go` ile kalkacağı için sheet kök navigator'ın bağlamıyla açılıyor.
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
