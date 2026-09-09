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
      final assignment = await _service.fetchAssignment(widget.assignmentId);
      if (!mounted) return;
      setState(() {
        _assignment = assignment;
        _isLoading = false;
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
