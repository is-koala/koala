import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/session_view.dart';

/// İşverenin açık oturumları.
///
/// Liste iki uygulamada da aynı — gövde [SessionView]'den geliyor. Tek fark
/// alt boşluk: bu taraftaki navbar sabit duruyor.
class BSessionsPage extends StatelessWidget {
  const BSessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Oturumlar'),
      body: const SessionView(bottomPadding: AppSizes.navBarClearance),
    );
  }
}
