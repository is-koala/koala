import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/settings/presentation/pages/settings_page.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kazançlarım satırı kazanç ekranını açar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/earnings',
          builder: (context, state) => const Text('Kazanç hedefi'),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kazançlarım'));
    await tester.pumpAndSettle();

    expect(find.text('Kazanç hedefi'), findsOneWidget);
  });
}
