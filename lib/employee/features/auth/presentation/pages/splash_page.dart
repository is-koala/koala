import 'dart:async';

import 'package:flutter/material.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/services/firebase_messaging_push_token_source.dart';
import 'package:koala/product/services/push_messaging.dart';
import 'package:koala/product/services/push_token_lifecycle.dart';
import 'package:provider/provider.dart';

/// Uygulamanın açılış ekranı ve tek başlatma noktası.
///
/// Oturum durumunu diskten okuma işi burada: `main` senkron kalıyor, ilk kare
/// gecikmeden çiziliyor ve okuma bitene kadar kullanıcı boş ekrana bakmıyor.
/// Okuma bitince [SessionManager] dinleyicilerini uyandırıyor, router'ın
/// muhafızı da kullanıcıyı gideceği yere yolluyor — bu sayfa kendisi
/// yönlendirme yapmıyor.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  /// Logonun kenar uzunluğu; açılış ekranının tek görseli olduğu için
  /// sayfa içi görsellerden büyük.
  static const double _logoSize = 120;

  @override
  void initState() {
    super.initState();
    // İlk kare çizildikten sonra: açılış görseli okuma beklerken görünsün.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final session = SessionManager();
    await session.load();
    if (!mounted) return;
    if (session.isLoggedIn) {
      // Kimlik inceleme durumu açılışta arka planda okunuyor: profil rozeti
      // ve kimlik ekranı açıldığında bekletmeden çizilsin. Beklenmiyor —
      // ağ yavaşsa açılışı geciktirmemeli; sonuç provider'a düşüyor.
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
