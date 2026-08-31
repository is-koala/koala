import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/notification_view.dart';

/// İşverenin bildirimleri.
///
/// Liste iki uygulamada da aynı — gövde [NotificationView]'den geliyor.
/// Tek fark alt boşluk: bu taraftaki navbar sabit duruyor, son satır onun
/// altında kalmasın.
class BNotificationsPage extends StatelessWidget {
  const BNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(
        title: 'Bildirimler',
        actions: [MarkAllReadAction()],
      ),
      body: const NotificationView(bottomPadding: AppSizes.navBarClearance),
    );
  }
}
