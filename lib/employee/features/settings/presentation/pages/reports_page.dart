import 'package:flutter/material.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/report_view.dart';

/// Çalışanın açtığı şikayetler.
///
/// Liste iki uygulamada da aynı — gövde [ReportView]'den geliyor.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Şikayetlerim'),
      body: const ReportView(),
    );
  }
}
