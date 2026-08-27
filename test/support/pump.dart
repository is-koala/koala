import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/theme/theme.dart';

/// Bir widget'ı uygulamanın gerçek teması içinde çizer.
///
/// Ürün widget'larının çoğu renklerini `context` üzerinden okuyor, yani
/// `MaterialApp` ve gerçek `ThemeData` olmadan çizilemiyorlar. Testin
/// `brightness` vermesi de mümkün: aynı widget'ı iki temada da doğrulamak
/// projenin temel kuralı.
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
