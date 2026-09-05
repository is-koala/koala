import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/blocked_users_view.dart';
import 'package:koala/product/widgets/my_appbar.dart';

/// İşverenin engellediği kullanıcılar.
///
/// Liste iki uygulamada da aynı — gövde [BlockedUsersView]'den geliyor. Tek
/// fark alt boşluk: bu taraftaki navbar sabit duruyor.
class BBlockedUsersPage extends StatelessWidget {
  const BBlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Engellediklerim'),
      body: const BlockedUsersView(bottomPadding: AppSizes.navBarClearance),
    );
  }
}
