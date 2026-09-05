import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:koala/product/network/api_config.dart';
import 'package:koala/product/network/app_update_gate.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/router/app_link_coordinator.dart';
import 'package:koala/product/router/router_manager.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:koala/product/widgets/update_required_view.dart';
import 'package:provider/provider.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final SessionManager _sessionManager;
  late final AppLinkCoordinator _appLinkCoordinator;
  StreamSubscription<Uri>? _appLinkSubscription;

  @override
  void initState() {
    super.initState();
    _sessionManager = SessionManager();
    _appLinkCoordinator = AppLinkCoordinator(appScheme: ApiConfig.appUrlScheme);
    _sessionManager.addListener(_flushPendingDeepLink);
    _appLinkSubscription = AppLinks().uriLinkStream.listen(_handleDeepLink);
  }

  /// Backend'in ürettiği kayıt, şifre ve ödeme bağlantılarını çalışan
  /// flavor'ın özel şemasıyla doğrulayıp oturum hazır olduğunda açar.
  void _handleDeepLink(Uri uri) {
    _appLinkCoordinator.handle(
      uri,
      sessionInitialized: _sessionManager.isInitialized,
      navigate: _navigate,
    );
  }

  void _flushPendingDeepLink() {
    _appLinkCoordinator.flush(
      sessionInitialized: _sessionManager.isInitialized,
      navigate: _navigate,
    );
  }

  void _navigate(String route) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) RouterManager.router.go(route);
    });
  }

  @override
  void dispose() {
    _sessionManager.removeListener(_flushPendingDeepLink);
    final subscription = _appLinkSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Koala',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: context.watch<ThemeProvider>().themeMode,
      routerConfig: RouterManager.router,
      // Sürüm kapısı her uçtan gelebildiği için yönlendirmeyle değil,
      // uygulamanın üstünü kapatarak karşılanıyor: hangi ekranda olursa
      // olsun sonuç aynı ve geri dönülecek bir yer yok.
      builder: (context, child) => ValueListenableBuilder<String?>(
        valueListenable: AppUpdateGate().message,
        builder: (context, message, _) => message == null
            ? (child ?? const SizedBox.shrink())
            : UpdateRequiredView(message: message),
      ),
    );
  }
}
