import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/my_button.dart';

/// Iyzico dönüş URL'sinin açtığı ekran.
///
/// URL'deki `status` yalnızca sağlayıcının yönlendirme ipucudur. Gösterilen
/// sonuç her zaman authenticated assignment listesinden yeniden okunur.
class PaymentResultPage extends StatefulWidget {
  const PaymentResultPage({
    super.key,
    required this.assignmentId,
    required this.hintedStatus,
    this.service,
  });

  final String assignmentId;
  final String hintedStatus;
  final EmployerJobService? service;

  @override
  State<PaymentResultPage> createState() => _PaymentResultPageState();
}

class _PaymentResultPageState extends State<PaymentResultPage> {
  bool _isLoading = true;
  String? _error;
  Assignment? _assignment;

  EmployerJobService get _service => widget.service ?? EmployerJobService();

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

  bool get _isSecured {
    final payment = _assignment?.paymentStatus;
    return payment == PaymentStatus.heldInEscrow ||
        payment == PaymentStatus.releasedToWorker;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ödeme Sonucu')),
      body: SafeArea(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isSecured ? Icons.verified_user_outlined : Icons.info_outline,
                size: 72,
                color: _isSecured ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              Text(
                _isSecured ? 'Ödeme Güvende' : 'Ödeme Henüz Doğrulanmadı',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.spaceSmall),
              Text(
                _error ??
                    (_isSecured
                        ? 'Ücret Koala güvencesinde tutuluyor. Çalışan artık '
                              'mesaiye başlayabilir.'
                        : 'Sağlayıcı sonucu işleniyor olabilir. Birkaç saniye '
                              'sonra tekrar kontrol et.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.sectionSpace),
              MyButton(onPressed: _load, title: 'TEKRAR KONTROL ET'),
              if (_assignment != null) ...[
                const SizedBox(height: AppSizes.spaceMedium),
                MyButton(
                  isReversed: true,
                  onPressed: () => context.go(
                    '/business/job-detail',
                    extra: _assignment!.job.id,
                  ),
                  title: 'İLANA DÖN',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
