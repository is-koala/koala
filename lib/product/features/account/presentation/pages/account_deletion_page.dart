import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/auth/services/legal_service.dart';
import 'package:koala/employee/features/jobs/presentation/providers/boarding_queue_provider.dart';
import 'package:koala/product/models/account_deletion.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/account_deletion_view.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

/// Hesap silme talebi; iki taraf aynı ekranı kullanıyor.
class AccountDeletionPage extends StatelessWidget {
  const AccountDeletionPage({super.key});

  /// Talep kabul edilince cihazda bekleyen biniş okutmaları (token ve konum
  /// taşıyorlar) silinir (#217).
  static Future<AccountDeletion> _requestDeletion(
    BuildContext context, {
    String? reason,
  }) async {
    final queue = Provider.of<BoardingQueueProvider?>(context, listen: false);
    final deletion = await LegalService().requestAccountDeletion(
      reason: reason,
    );
    await queue?.purgeActiveUser();
    return deletion;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Hesabı Sil'),
      body: AccountDeletionView(
        requestDeletion: ({String? reason}) =>
            _requestDeletion(context, reason: reason),
      ),
    );
  }
}
