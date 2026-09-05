import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/services/employer_job_service.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_button.dart';

part 'b_payment_result_pagemodel.dart';

/// Iyzico dönüş URL'sinin açtığı ekran.
///
/// Gösterilen sonuç her zaman authenticated assignment listesinden yeniden
/// okunur; yönlendirme URL'sindeki sağlayıcı durumu finansal kanıt değildir.
class BPaymentResultPage extends StatefulWidget {
  const BPaymentResultPage({
    super.key,
    required this.assignmentId,
    this.service,
  });

  final String assignmentId;
  final EmployerJobService? service;

  @override
  State<BPaymentResultPage> createState() => _BPaymentResultPageState();
}

class _BPaymentResultPageState extends BPaymentResultPagemodel {
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
              AppIcon(
                _isSecured ? AppIcons.shield : AppIcons.info,
                size: AppSizes.iconHuge,
                color: _isSecured ? AppColors.success : AppColors.warning,
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
