import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/session_view.dart';

/// Hesabın açık oturumları.
///
/// Oturum kullanıcıya ait, tarafına değil: iki uygulamanın ayarları da bu
/// ekranı açıyor. Gövde [SessionView]'den geliyor; alt pay, liste uzadığında
/// son satırın sistem çubuğuna yapışmaması için.
class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Oturumlar'),
      body: const SessionView(bottomPadding: AppSizes.navBarClearance),
    );
  }
}
