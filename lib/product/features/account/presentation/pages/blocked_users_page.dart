import 'package:flutter/material.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/account/presentation/widgets/account_list_clearance.dart';
import 'package:koala/product/widgets/blocked_users_view.dart';
import 'package:koala/product/widgets/my_appbar.dart';

/// Hesabın engellediği kullanıcılar.
///
/// Engel listesi kullanıcıya ait, tarafına değil: iki uygulamanın ayarları
/// da bu ekranı açıyor. Gövde [BlockedUsersView]'den geliyor; alt pay kabuğa
/// göre ([AccountListClearance]).
class BlockedUsersPage extends StatelessWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Engellediklerim'),
      body: BlockedUsersView(
        bottomPadding: AccountListClearance.bottomPadding(),
      ),
    );
  }
}
