import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_button.dart';

part 'b_payment_result_pagemodel.dart';

/// Iyzico dönüş URL'sinin açtığı ekran.
///
/// Gösterilen sonuç her zaman kimlik doğrulamalı tekil atama ucundan yeniden
/// okunur; yönlendirme URL'sindeki sağlayıcı durumu finansal kanıt değildir.
class BPaymentResultPage extends StatefulWidget {
  const BPaymentResultPage({
    super.key,
    required this.assignmentId,
    this.service,
    this.now,
    this.delay,
  });

  final String assignmentId;

  /// Tekil atama okuması çalışan tarafındaki servisten geliyor: uç iki
  /// tarafa da açık ve mesai oturumları gibi tek servis iki kabuğa hizmet
  /// ediyor. Testler için; verilmezse üretimdeki tekil servis.
  final AssignmentService? service;
  final DateTime Function()? now;
  final Future<void> Function(Duration)? delay;

  @override
  State<BPaymentResultPage> createState() => _BPaymentResultPageState();
}

class _BPaymentResultPageState extends BPaymentResultPagemodel {
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Semantics(
            container: true,
            liveRegion: true,
            label: 'Ödeme sonucu kontrol ediliyor.',
            excludeSemantics: true,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: AppSizes.spaceSmall),
                Text('Ödeme sonucu kontrol ediliyor.'),
              ],
            ),
          ),
        ),
      );
    }

    final presentation = _presentation;

    return Scaffold(
      appBar: AppBar(title: const Text('Ödeme Sonucu')),
      body: SafeArea(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                key: const ValueKey('payment-result-status'),
                container: true,
                liveRegion: true,
                label: '${presentation.title}. ${presentation.message}',
                excludeSemantics: true,
                child: Column(
                  children: [
                    AppIcon(
                      presentation.icon,
                      size: AppSizes.iconHuge,
                      color: presentation.color,
                    ),
                    const SizedBox(height: AppSizes.spaceMedium),
                    Text(
                      presentation.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSizes.spaceSmall),
                    Text(presentation.message, textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.sectionSpace),
              MyButton(
                onPressed: _isRefreshing ? null : _retry,
                title: 'TEKRAR KONTROL ET',
              ),
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
