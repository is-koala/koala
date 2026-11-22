import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/theme/theme.dart';

/// Widget'ı uygulamanın gerçek temasında çizer; iki temada doğrulamak için
/// `brightness` verilebilir.
Future<void> pumpInApp(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? darkTheme : lightTheme,
      home: Scaffold(body: child),
    ),
  );
}
