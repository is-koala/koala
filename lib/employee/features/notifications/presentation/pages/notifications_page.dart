import 'package:flutter/material.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/notification_view.dart';

/// Çalışanın bildirimleri.
///
/// Liste iki uygulamada da aynı — gövde [NotificationView]'den geliyor,
/// burada yalnızca başlık çubuğu kuruluyor.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(
        title: 'Bildirimler',
        actions: [MarkAllReadAction()],
      ),
      body: const NotificationView(),
    );
  }
}
