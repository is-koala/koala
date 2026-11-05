import 'package:flutter/material.dart';
import 'package:koala/employee/features/auth/services/legal_service.dart';
import 'package:koala/employee/features/jobs/presentation/providers/boarding_queue_provider.dart';
import 'package:koala/product/models/account_deletion.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/account_deletion_view.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

/// Hesap silme talebi.
///
/// Silme hesabın kendisine ait: çalışan da işveren de aynı ekrandan,
/// aynı `LegalService` çağrısıyla talep açıyor. Gövde
/// [AccountDeletionView]'den geliyor.
class AccountDeletionPage extends StatelessWidget {
  const AccountDeletionPage({super.key});

  /// Talep kabul edilince cihazda bekleyen servis biniş okutmaları
  /// (token ve konum taşıyorlar) silinir (is-koala/koala#217). Kuyruk
  /// yalnız uygulama ağacında var; testte ya da işveren oturumunda boş
  /// geçilir.
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
