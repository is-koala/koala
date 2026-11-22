import 'package:material_ui/material_ui.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/account/presentation/widgets/account_list_clearance.dart';
import 'package:koala/product/services/session_service.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/session_view.dart';

/// Açık oturumlar; gövde [SessionView], alt pay [AccountListClearance].
class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key, this.service});

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
