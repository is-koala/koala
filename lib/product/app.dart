import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:koala/product/router/router_manager.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();

    final appLinks = AppLinks();

    appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  /// Backend `token` taşıyan iki farklı bağlantı üretiyor:
  /// `/complete-registration?token=...` (kayıt doğrulama) ve
  /// `/reset-password?token=...` (şifre sıfırlama). İkisi de aynı sorgu
  /// parametresini kullandığı için hangi akış olduğuna yola bakarak karar
  /// veriliyor; özel şemada (`koala://complete-registration?...`) yol boş
  /// kalıp değer `host`'a düştüğü için ikisi birlikte kontrol ediliyor.
  void _handleDeepLink(Uri uri) {
    final token = uri.queryParameters['token'];
    if (token == null) return;

    final target = '${uri.host}${uri.path}';

    if (target.contains('complete-registration')) {
      RouterManager.router.go(
        '/auth/register-type/register/creating-password'
        '?token=${Uri.encodeQueryComponent(token)}',
      );
    }

    // TODO(backend): `reset-password` bağlantısının açacağı ekran henüz yok.
    // Eklenene kadar bu bağlantı yok sayılıyor; kayıt ekranına düşürmek
    // yanlış akışı başlatırdı.
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
    );
  }
}
