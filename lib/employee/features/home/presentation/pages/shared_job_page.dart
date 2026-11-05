import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/core/widgets/job_detail_bottom_sheet.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/router/router_manager.dart';
import 'package:koala/product/widgets/empty_state.dart';

part 'shared_job_pagemodel.dart';

/// Paylaşılan bir ilan bağlantısıyla (`/is-ilanlari/<id>`) gelen kullanıcının
/// ilk ekranı.
///
/// İlanı kimlikle yüklüyor, sonra keşfet sekmesine geçip ilanın detay
/// sheet'ini açıyor: kullanıcı ilanı uygulamadaki her ilan gibi görüyor ve
/// sheet kapanınca keşfette kalıyor. İlan yoksa ya da kapanmışsa bunu söyleyip
/// keşfete dönüş sunuyor.
class SharedJobPage extends StatefulWidget {
  const SharedJobPage({super.key, required this.jobId, this.jobService});

  final String jobId;

  /// Testte sahte sunucuya bağlı servis; üretimde `null`.
  final JobService? jobService;

  @override
  State<SharedJobPage> createState() => _SharedJobPageState();
}

class _SharedJobPageState extends SharedJobPageModel {
  @override
  Widget build(BuildContext context) {
    final error = errorMessage;
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: error == null
          ? Center(child: CircularProgressIndicator(color: context.accentColor))
          : EmptyState(
              icon: AppIcons.work,
              title: 'İlan açılamadı',
              description: error,
              action: TextButton(
                onPressed: openExplore,
                child: const Text('Keşfete Dön'),
              ),
            ),
    );
  }
}
