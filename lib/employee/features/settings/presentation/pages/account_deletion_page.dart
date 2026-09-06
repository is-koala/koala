import 'package:flutter/material.dart';
import 'package:koala/employee/features/auth/services/legal_service.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/account_deletion_view.dart';
import 'package:koala/product/widgets/my_appbar.dart';

class AccountDeletionPage extends StatelessWidget {
  const AccountDeletionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Hesabı Sil'),
      body: AccountDeletionView(
        requestDeletion: LegalService().requestAccountDeletion,
      ),
    );
  }
}
