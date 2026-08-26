import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:koala/product/router/router_manager.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    final appLinks = AppLinks();

    appLinks.uriLinkStream.listen((uri) async {
      final token = uri.queryParameters['token'];
      if (token != null) {
        RouterManager.router.go(
          '/auth/register-type/register/creating-password?token=$token',
        );
      }
    });
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
