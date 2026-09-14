import 'package:flutter/material.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/account/presentation/widgets/account_list_clearance.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/report_view.dart';

/// Hesabın açtığı şikayetler.
///
/// İki uygulamanın ayarları da bu ekranı açıyor; gövde [ReportView]'den
/// geliyor, alt pay kabuğa göre ([AccountListClearance]).
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Şikayetlerim'),
      body: ReportView(bottomPadding: AccountListClearance.bottomPadding()),
    );
  }
}
