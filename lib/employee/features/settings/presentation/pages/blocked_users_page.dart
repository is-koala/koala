import 'package:flutter/material.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/blocked_users_view.dart';
import 'package:koala/product/widgets/my_appbar.dart';

/// Çalışanın engellediği kullanıcılar.
///
/// Liste iki uygulamada da aynı — gövde [BlockedUsersView]'den geliyor.
class BlockedUsersPage extends StatelessWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Engellediklerim'),
      body: const BlockedUsersView(),
    );
  }
}
