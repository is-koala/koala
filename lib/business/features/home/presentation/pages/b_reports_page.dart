import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/report_view.dart';

/// İşverenin açtığı şikayetler.
///
/// Liste iki uygulamada da aynı — gövde [ReportView]'den geliyor. Tek fark
/// alt boşluk: bu taraftaki navbar sabit duruyor.
class BReportsPage extends StatelessWidget {
  const BReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Şikayetlerim'),
      body: const ReportView(bottomPadding: AppSizes.navBarClearance),
    );
  }
}
