part of 'b_payment_result_page.dart';

abstract class BPaymentResultPagemodel extends State<BPaymentResultPage> {
  bool _isLoading = true;
  String? _error;
  Assignment? _assignment;

  EmployerJobService get _service => widget.service ?? EmployerJobService();

  bool get _isSecured => _assignment?.paymentStatus.isSecured ?? false;

  bool get _isFailed => _assignment?.paymentStatus == PaymentStatus.failed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await _service.fetchMyAssignments();
      final assignment = page.assignments
          .where((item) => item.id == widget.assignmentId)
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _assignment = assignment;
        _isLoading = false;
        if (assignment == null) _error = 'İş kaydı bulunamadı.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }
}
