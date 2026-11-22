import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/home/presentation/providers/page_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/services/firebase_messaging_push_token_source.dart';
import 'package:koala/product/services/maps_availability.dart';
import 'package:koala/product/services/push_messaging.dart';
import 'package:koala/product/services/push_token_lifecycle.dart';
import 'package:provider/provider.dart';

/// Açılış ekranı ve tek başlatma noktası; `main` senkron kalsın diye oturum
/// burada okunur. Yönlendirmeyi router muhafızı yapar.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const double _logoSize = 120;

  @override
  void initState() {
    super.initState();
    // Açılış görseli okuma beklerken görünsün.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    // Harita bayrağı oturumdan **önce**: muhafız kullanıcıyı hemen haritaya
    // yollar, cevabın gelmiş olması gerek (#172).
    final maps = context.read<MapsAvailability>();
    await maps.resolve();
    if (!mounted) return;
    if (!maps.isAvailable) {
      context.read<PageProvider>().setExploreViewToList();
    }

    final session = SessionManager();
    await session.load();
    if (!mounted) return;
    if (session.isLoggedIn) {
      // Profil rozeti ve kimlik ekranı bekletmesin diye arkada; açılışı
      // geciktirmemek için beklenmiyor.
      unawaited(context.read<IdentityReviewProvider>().load(silent: true));
    }
    await PushMessaging.ensureInitialized();
    final pushTokens = PushTokenLifecycle();
    if (PushMessaging.isReady) {
      pushTokens.useSource(FirebaseMessagingPushTokenSource());
    }
    pushTokens.listen();
    await pushTokens.syncQuietly();
    if (!mounted) return;
    await PushMessaging.bindListeners(
      notifications: context.read<NotificationProvider>(),
      users: context.read<UserProvider>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _logoSize,
              child: Image.asset(AppAssets.koalaLogoAlt),
            ),
            const SizedBox(height: AppSizes.spaceLarge),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
