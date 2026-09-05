import 'package:flutter/material.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/session_view.dart';

/// Çalışanın açık oturumları.
///
/// Liste iki uygulamada da aynı — gövde [SessionView]'den geliyor.
class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Oturumlar'),
      body: const SessionView(),
    );
  }
}
