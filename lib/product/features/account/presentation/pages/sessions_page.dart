import 'package:flutter/material.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/account/presentation/widgets/account_list_clearance.dart';
import 'package:koala/product/services/session_service.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/session_view.dart';

/// Hesabın açık oturumları.
///
/// Oturum kullanıcıya ait, tarafına değil: iki uygulamanın ayarları da bu
/// ekranı açıyor. Gövde [SessionView]'den geliyor; alt pay kabuğa göre
/// ([AccountListClearance]). Satıra dokununca [SessionDetailPage] açılıyor.
class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key, this.service});

  /// Testlerde sahte sunucuya bağlı örnek geçilebilsin diye.
  final SessionService? service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Oturumlar'),
      body: SessionView(
        bottomPadding: AccountListClearance.bottomPadding(),
        service: service,
      ),
    );
  }
}
